package com.signal.app.features.avatar.presentation.screens

import androidx.compose.animation.*
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.signal.app.R
import com.signal.app.features.avatar.data.models.*
import com.signal.app.features.avatar.presentation.viewmodel.AvatarViewModel
import com.signal.app.features.avatar.presentation.components.*
import com.signal.app.ui.components.LoadingOverlay
import com.signal.app.ui.components.ErrorSnackbar
import com.signal.app.ui.theme.SignalTheme

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AvatarSelectionScreen(
    userId: Int,
    onAvatarSelected: (Avatar) -> Unit,
    onNavigateBack: () -> Unit,
    viewModel: AvatarViewModel = hiltViewModel()
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    val searchQuery by viewModel.searchQuery.collectAsStateWithLifecycle()
    val personalityInsights by viewModel.personalityInsights.collectAsStateWithLifecycle()

    LaunchedEffect(userId) {
        viewModel.loadUserAvatarData(userId)
    }

    // Show error snackbar
    state.error?.let { error ->
        LaunchedEffect(error) {
            // Show error and clear it
            viewModel.clearError()
        }
    }

    Scaffold(
        topBar = {
            AvatarSelectionTopBar(
                currentAvatar = state.userAvatarData?.currentAvatar?.avatar,
                onNavigateBack = onNavigateBack,
                onRefresh = { viewModel.refreshData(userId) }
            )
        },
        bottomBar = {
            AvatarTabBar(
                currentTab = state.currentTab,
                onTabSelected = viewModel::switchTab,
                favoriteCount = state.userAvatarData?.favoriteAvatars?.size ?: 0,
                recentCount = state.userAvatarData?.recentAvatars?.size ?: 0
            )
        }
    ) { paddingValues ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
        ) {
            Column(
                modifier = Modifier.fillMaxSize()
            ) {
                // Search bar for search tab
                AnimatedVisibility(
                    visible = state.currentTab == AvatarTab.SEARCH,
                    enter = slideInVertically() + fadeIn(),
                    exit = slideOutVertically() + fadeOut()
                ) {
                    AvatarSearchBar(
                        query = searchQuery,
                        onQueryChange = viewModel::updateSearchQuery,
                        isSearching = state.isSearching,
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(16.dp)
                    )
                }

                // Main content
                when (state.currentTab) {
                    AvatarTab.CATEGORIES -> {
                        CategoryTabContent(
                            categories = state.categories,
                            selectedCategory = state.selectedCategory,
                            avatars = state.avatars,
                            userAvatarData = state.userAvatarData,
                            onCategorySelected = viewModel::loadAvatarsByCategory,
                            onAvatarSelected = { avatar ->
                                viewModel.selectAvatar(userId, avatar)
                                onAvatarSelected(avatar)
                            },
                            onToggleFavorite = { avatar, isFavorite ->
                                viewModel.toggleFavorite(userId, avatar, isFavorite)
                            },
                            isFavorite = viewModel::isFavorite
                        )
                    }
                    AvatarTab.FAVORITES -> {
                        FavoriteTabContent(
                            favoriteAvatars = state.userAvatarData?.favoriteAvatars ?: emptyList(),
                            onAvatarSelected = { avatar ->
                                viewModel.selectAvatar(userId, avatar)
                                onAvatarSelected(avatar)
                            },
                            onToggleFavorite = { avatar, isFavorite ->
                                viewModel.toggleFavorite(userId, avatar, isFavorite)
                            }
                        )
                    }
                    AvatarTab.RECENT -> {
                        RecentTabContent(
                            recentAvatars = state.userAvatarData?.recentAvatars ?: emptyList(),
                            onAvatarSelected = { avatar ->
                                viewModel.selectAvatar(userId, avatar)
                                onAvatarSelected(avatar)
                            },
                            onToggleFavorite = { avatar, isFavorite ->
                                viewModel.toggleFavorite(userId, avatar, isFavorite)
                            },
                            isFavorite = viewModel::isFavorite
                        )
                    }
                    AvatarTab.SEARCH -> {
                        SearchTabContent(
                            searchResults = state.searchResults,
                            searchQuery = searchQuery,
                            isSearching = state.isSearching,
                            onAvatarSelected = { avatar ->
                                viewModel.selectAvatar(userId, avatar)
                                onAvatarSelected(avatar)
                            },
                            onToggleFavorite = { avatar, isFavorite ->
                                viewModel.toggleFavorite(userId, avatar, isFavorite)
                            },
                            isFavorite = viewModel::isFavorite
                        )
                    }
                    AvatarTab.PERSONALITY -> {
                        PersonalityTabContent(
                            personalityInsights = personalityInsights,
                            personalityAnalysis = state.userAvatarData?.personalityAnalysis,
                            usageStats = state.userAvatarData?.usageStats
                        )
                    }
                }
            }

            // Loading overlay
            if (state.isLoading) {
                LoadingOverlay()
            }

            // Error snackbar
            state.error?.let { error ->
                ErrorSnackbar(
                    message = error,
                    onDismiss = viewModel::clearError,
                    modifier = Modifier.align(Alignment.BottomCenter)
                )
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun AvatarSelectionTopBar(
    currentAvatar: Avatar?,
    onNavigateBack: () -> Unit,
    onRefresh: () -> Unit
) {
    TopAppBar(
        title = {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                // Current avatar display
                if (currentAvatar != null) {
                    Surface(
                        modifier = Modifier.size(32.dp),
                        shape = CircleShape,
                        color = MaterialTheme.colorScheme.surfaceVariant
                    ) {
                        Box(
                            modifier = Modifier.fillMaxSize(),
                            contentAlignment = Alignment.Center
                        ) {
                            Text(
                                text = currentAvatar.emoji,
                                style = MaterialTheme.typography.titleMedium
                            )
                        }
                    }
                }
                
                Column {
                    Text(
                        text = stringResource(R.string.select_avatar),
                        style = MaterialTheme.typography.titleLarge
                    )
                    if (currentAvatar != null) {
                        Text(
                            text = currentAvatar.getDisplayName(),
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
            }
        },
        navigationIcon = {
            IconButton(onClick = onNavigateBack) {
                Icon(
                    imageVector = Icons.Default.ArrowBack,
                    contentDescription = stringResource(R.string.back)
                )
            }
        },
        actions = {
            IconButton(onClick = onRefresh) {
                Icon(
                    imageVector = Icons.Default.Refresh,
                    contentDescription = stringResource(R.string.refresh)
                )
            }
        }
    )
}

@Composable
private fun AvatarTabBar(
    currentTab: AvatarTab,
    onTabSelected: (AvatarTab) -> Unit,
    favoriteCount: Int,
    recentCount: Int
) {
    NavigationBar(
        modifier = Modifier.fillMaxWidth()
    ) {
        // Categories tab
        NavigationBarItem(
            selected = currentTab == AvatarTab.CATEGORIES,
            onClick = { onTabSelected(AvatarTab.CATEGORIES) },
            icon = {
                Icon(
                    imageVector = Icons.Default.Category,
                    contentDescription = null
                )
            },
            label = {
                Text(stringResource(R.string.categories))
            }
        )

        // Favorites tab
        NavigationBarItem(
            selected = currentTab == AvatarTab.FAVORITES,
            onClick = { onTabSelected(AvatarTab.FAVORITES) },
            icon = {
                BadgedBox(
                    badge = {
                        if (favoriteCount > 0) {
                            Badge {
                                Text(favoriteCount.toString())
                            }
                        }
                    }
                ) {
                    Icon(
                        imageVector = Icons.Default.Favorite,
                        contentDescription = null
                    )
                }
            },
            label = {
                Text(stringResource(R.string.favorites))
            }
        )

        // Recent tab
        NavigationBarItem(
            selected = currentTab == AvatarTab.RECENT,
            onClick = { onTabSelected(AvatarTab.RECENT) },
            icon = {
                BadgedBox(
                    badge = {
                        if (recentCount > 0) {
                            Badge {
                                Text(recentCount.toString())
                            }
                        }
                    }
                ) {
                    Icon(
                        imageVector = Icons.Default.History,
                        contentDescription = null
                    )
                }
            },
            label = {
                Text(stringResource(R.string.recent))
            }
        )

        // Search tab
        NavigationBarItem(
            selected = currentTab == AvatarTab.SEARCH,
            onClick = { onTabSelected(AvatarTab.SEARCH) },
            icon = {
                Icon(
                    imageVector = Icons.Default.Search,
                    contentDescription = null
                )
            },
            label = {
                Text(stringResource(R.string.search))
            }
        )

        // Personality tab
        NavigationBarItem(
            selected = currentTab == AvatarTab.PERSONALITY,
            onClick = { onTabSelected(AvatarTab.PERSONALITY) },
            icon = {
                Icon(
                    imageVector = Icons.Default.Psychology,
                    contentDescription = null
                )
            },
            label = {
                Text(stringResource(R.string.personality))
            }
        )
    }
}