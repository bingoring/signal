package handlers

import (
	"signal-be/internal/services"
	"signal-be/internal/utils"
	"signal-module/pkg/logger"

	"github.com/gin-gonic/gin"
)

type DebugHandler struct {
	postgisInit *services.PostGISInitializer
	logger      *logger.Logger
}

func NewDebugHandler(postgisInit *services.PostGISInitializer, logger *logger.Logger) *DebugHandler {
	return &DebugHandler{
		postgisInit: postgisInit,
		logger:      logger,
	}
}

// GetPostGISInfo PostGIS 설치 및 설정 정보 조회
// @Summary Get PostGIS information
// @Description Returns PostGIS installation and configuration details
// @Tags Debug
// @Accept json
// @Produce json
// @Success 200 {object} map[string]interface{}
// @Router /api/v1/debug/postgis [get]
func (h *DebugHandler) GetPostGISInfo(c *gin.Context) {
	info, err := h.postgisInit.GetPostGISInfo()
	if err != nil {
		utils.InternalServerErrorResponse(c, "PostGIS 정보 조회 실패", err)
		return
	}

	utils.SuccessResponse(c, "PostGIS 정보 조회 완료", info)
}

// GetGeographicStatistics 지리적 통계 정보 조회
// @Summary Get geographic statistics
// @Description Returns statistical information about geographic data
// @Tags Debug
// @Accept json
// @Produce json
// @Success 200 {object} map[string]interface{}
// @Router /api/v1/debug/geographic-stats [get]
func (h *DebugHandler) GetGeographicStatistics(c *gin.Context) {
	stats, err := h.postgisInit.GetGeographicStatistics()
	if err != nil {
		utils.InternalServerErrorResponse(c, "지리적 통계 조회 실패", err)
		return
	}

	utils.SuccessResponse(c, "지리적 통계 조회 완료", stats)
}

// ValidateGeographicData 지리적 데이터 유효성 재검사
// @Summary Validate geographic data
// @Description Re-validates all geographic data in the database
// @Tags Debug
// @Accept json
// @Produce json
// @Success 200 {object} map[string]interface{}
// @Router /api/v1/debug/validate-geographic [post]
func (h *DebugHandler) ValidateGeographicData(c *gin.Context) {
	if err := h.postgisInit.ValidateGeographicData(); err != nil {
		utils.InternalServerErrorResponse(c, "지리적 데이터 검증 실패", err)
		return
	}

	utils.SuccessResponse(c, "지리적 데이터 검증 완료", gin.H{
		"status": "validated",
		"timestamp": utils.CurrentTime(),
	})
}