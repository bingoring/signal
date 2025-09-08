package main

import (
	"context"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"signal-be/internal/handlers"
	"signal-be/internal/middleware"
	"signal-be/internal/repositories"
	"signal-be/internal/services"

	"signal-module/pkg/config"
	"signal-module/pkg/database"
	"signal-module/pkg/logger"
	"signal-module/pkg/queue"
	"signal-module/pkg/redis"
	"signal-module/pkg/utils"

	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"
)

func main() {
	cfg := config.LoadConfig()

	appLogger := logger.New("signal-be")
	appLogger.Info("🚀 Signal Backend 시작 중...")

	db, err := database.New(&cfg.Database)
	if err != nil {
		appLogger.Error("데이터베이스 연결 실패", err)
		os.Exit(1)
	}
	defer db.Close()

	if err := db.Migrate(); err != nil {
		appLogger.Error("데이터베이스 마이그레이션 실패", err)
		os.Exit(1)
	}

	redisClient, err := redis.New(&cfg.Redis)
	if err != nil {
		appLogger.Error("Redis 연결 실패", err)
		os.Exit(1)
	}
	defer redisClient.Close()

	jwtManager := utils.NewJWTManager(&cfg.JWT)
	jobQueue := queue.New(redisClient)

	userRepo := repositories.NewUserRepository(db.DB)
	signalRepo := repositories.NewSignalRepository(db.DB)
	chatRepo := repositories.NewChatRepository(db.DB)
	buddyRepo := repositories.NewBuddyRepository(db.DB)

	websocketService := services.NewWebSocketService(appLogger, redisClient)

	userService := services.NewUserService(userRepo, jwtManager, appLogger)
	signalService := services.NewSignalService(signalRepo, userRepo, redisClient, jobQueue, appLogger, websocketService)
	chatService := services.NewChatService(chatRepo, signalRepo, redisClient, appLogger)
	buddyService := services.NewBuddyService(buddyRepo, userRepo, appLogger)
	stdLogger := log.New(os.Stdout, "[CHAT-WS] ", log.LstdFlags)
	chatWebSocketService := services.NewChatWebSocketService(db.DB, stdLogger)

	// Email service for magic links
	emailService := services.NewEmailService(
		cfg.SMTP.Host,
		cfg.SMTP.Port,
		cfg.SMTP.Username,
		cfg.SMTP.Password,
		cfg.SMTP.FromEmail,
		cfg.SMTP.FromName,
	)
	
	// Auth service with magic link support
	authService := services.NewAuthService(db.DB, emailService, cfg.JWT.Secret, cfg.Server.FrontendURL)

	userHandler := handlers.NewUserHandler(userService, appLogger)
	authHandler := handlers.NewAuthHandler(userService, authService, appLogger)
	oauthHandler := handlers.NewOAuthHandler(cfg, userService, appLogger)
	signalHandler := handlers.NewSignalHandler(signalService, appLogger)
	chatHandler := handlers.NewChatHandler(chatService, chatWebSocketService, appLogger)
	buddyHandler := handlers.NewBuddyHandler(buddyService, appLogger)

	router := setupRouter(cfg, userHandler, authHandler, oauthHandler, signalHandler, chatHandler, buddyHandler, websocketService, jwtManager, appLogger)

	server := &http.Server{
		Addr:    ":" + cfg.Server.Port,
		Handler: router,
	}

	go func() {
		appLogger.Info("🌐 서버가 포트 " + cfg.Server.Port + "에서 실행 중입니다")
		if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			appLogger.Error("서버 시작 실패", err)
			os.Exit(1)
		}
	}()

	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	appLogger.Info("🛑 서버 종료 중...")

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	if err := server.Shutdown(ctx); err != nil {
		appLogger.Error("서버 강제 종료", err)
		os.Exit(1)
	}

	appLogger.Info("✅ 서버가 정상적으로 종료되었습니다")
}

func setupRouter(
	cfg *config.Config,
	userHandler *handlers.UserHandler,
	authHandler *handlers.AuthHandler,
	oauthHandler *handlers.OAuthHandler,
	signalHandler *handlers.SignalHandler,
	chatHandler *handlers.ChatHandler,
	buddyHandler *handlers.BuddyHandler,
	websocketService *services.WebSocketService,
	jwtManager *utils.JWTManager,
	appLogger *logger.Logger,
) *gin.Engine {
	if cfg.Server.Mode == "release" {
		gin.SetMode(gin.ReleaseMode)
	}

	router := gin.New()
	router.Use(gin.Logger())
	router.Use(gin.Recovery())

	corsConfig := cors.Config{
		AllowOrigins:     []string{cfg.Server.FrontendURL, "http://localhost:3000"},
		AllowMethods:     []string{"GET", "POST", "PUT", "PATCH", "DELETE", "HEAD", "OPTIONS"},
		AllowHeaders:     []string{"Origin", "Content-Length", "Content-Type", "Authorization"},
		AllowCredentials: true,
		MaxAge:           12 * time.Hour,
	}
	router.Use(cors.New(corsConfig))

	authMiddleware := middleware.NewAuthMiddleware(jwtManager, appLogger)

	api := router.Group("/api/v1")
	{
		// 인증 불필요
		auth := api.Group("/auth")
		{
			auth.POST("/register", authHandler.Register)
			auth.POST("/login", authHandler.Login)
			auth.POST("/refresh", authHandler.RefreshToken)
			
			// Magic Link Authentication
			auth.POST("/magic-link", authHandler.SendMagicLink)
			auth.GET("/verify", authHandler.VerifyMagicLink)
			
			// OAuth 로그인
			auth.GET("/:provider/login", oauthHandler.StartOAuthLogin)
			auth.GET("/:provider/callback", oauthHandler.OAuthCallback)
			auth.GET("/oauth/providers", oauthHandler.GetSupportedProviders)
		}

		// 인증 필요
		authenticated := api.Group("")
		authenticated.Use(authMiddleware.RequireAuth())
		{
			// 인증 관리 (인증 필요)
			authSecure := authenticated.Group("/auth")
			{
				authSecure.GET("/profile", authHandler.GetProfile)
				authSecure.POST("/logout", authHandler.Logout)
			}

			// 사용자 관리
			user := authenticated.Group("/user")
			{
				user.GET("/profile", userHandler.GetProfile)
				user.PUT("/profile", userHandler.UpdateProfile)
				user.POST("/location", userHandler.UpdateLocation)
				user.POST("/interests", userHandler.UpdateInterests)
				user.POST("/push-token", userHandler.RegisterPushToken)
			}

			// 시그널 관리
			signals := authenticated.Group("/signals")
			{
				signals.POST("", signalHandler.CreateSignal)
				signals.GET("", signalHandler.SearchSignals)
				signals.GET("/nearby", signalHandler.GetNearbySignals)
				signals.GET("/my", signalHandler.GetMySignals)
				signals.GET("/:id", signalHandler.GetSignal)
				signals.POST("/:id/join", signalHandler.JoinSignal)
				signals.POST("/:id/leave", signalHandler.LeaveSignal)
				signals.POST("/:id/approve/:user_id", signalHandler.ApproveParticipant)
				signals.POST("/:id/reject/:user_id", signalHandler.RejectParticipant)
				// 실시간 시그널 업데이트 WebSocket
				signals.GET("/ws", websocketService.HandleSignalWebSocket)
			}

			// 채팅
			chat := authenticated.Group("/chat")
			{
				chat.GET("/rooms", chatHandler.GetChatRooms)
				chat.GET("/rooms/:id", chatHandler.GetChatRoom)
				chat.GET("/rooms/:id/messages", chatHandler.GetMessages)
				chat.POST("/rooms/:id/messages", chatHandler.SendMessage)
				chat.POST("/rooms/:id/join", chatHandler.JoinChatRoom)
				chat.POST("/signals/:signal_id/room", chatHandler.CreateChatRoom)
				chat.GET("/ws/:room_id", chatHandler.HandleWebSocket)
			}

			// 평가 및 신고
			ratings := authenticated.Group("/ratings")
			{
				ratings.POST("", userHandler.RateUser)
				ratings.POST("/report", userHandler.ReportUser)
			}

			// 단골 관리
			buddies := authenticated.Group("/buddies")
			{
				// 단골 목록 및 통계
				buddies.GET("", buddyHandler.GetBuddies)
				buddies.GET("/stats", buddyHandler.GetBuddyStats)
				buddies.GET("/potential", buddyHandler.GetPotentialBuddies)
				
				// 특정 단골 관리
				buddies.GET("/:buddyId", buddyHandler.GetBuddy)
				buddies.POST("", buddyHandler.CreateBuddy)
				buddies.PUT("/:buddyId", buddyHandler.UpdateBuddy)
				buddies.DELETE("/:buddyId", buddyHandler.DeleteBuddy)
				
				// 매너 점수 관리
				buddies.POST("/manner", buddyHandler.CreateMannerLog)
				buddies.GET("/manner/logs", buddyHandler.GetMannerLogs)
				
				// 단골 초대 관리
				buddies.POST("/invitations", buddyHandler.CreateBuddyInvitation)
				buddies.GET("/invitations", buddyHandler.GetBuddyInvitations)
				buddies.POST("/invitations/:invitationId/respond", buddyHandler.RespondBuddyInvitation)
			}
		}
	}

	// 헬스 체크
	router.GET("/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{
			"status":  "ok",
			"service": "signal-be",
			"time":    time.Now().Format(time.RFC3339),
		})
	})

	return router
}