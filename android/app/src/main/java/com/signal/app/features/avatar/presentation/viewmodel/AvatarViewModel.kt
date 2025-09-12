package com.signal.app.features.avatar.presentation.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.signal.app.core.network.ApiResult
import com.signal.app.features.avatar.data.models.*
import com.signal.app.features.avatar.data.repository.AvatarRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.FlowPreview
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch
import javax.inject.Inject

@OptIn(FlowPreview::class)
@HiltViewModel
class AvatarViewModel @Inject constructor(
    private val avatarRepository: AvatarRepository
) : ViewModel() {

    private val _state = MutableStateFlow(AvatarSelectionState())
    val state: StateFlow<AvatarSelectionState> = _state.asStateFlow()

    private val _searchQuery = MutableStateFlow("")
    val searchQuery: StateFlow<String> = _searchQuery.asStateFlow()

    private val _personalityInsights = MutableStateFlow<List<PersonalityInsight>>(emptyList())
    val personalityInsights: StateFlow<List<PersonalityInsight>> = _personalityInsights.asStateFlow()

    init {
        loadCategories()
        setupSearchFlow()
    }

    private fun setupSearchFlow() {
        _searchQuery
            .debounce(300)
            .distinctUntilChanged()
            .filter { it.length >= 2 }
            .onEach { query ->
                performSearch(query)
            }
            .launchIn(viewModelScope)
    }

    fun loadCategories() {
        viewModelScope.launch {
            _state.value = _state.value.copy(isLoading = true, error = null)
            
            avatarRepository.getAvatarCategories().collect { result ->
                when (result) {
                    is ApiResult.Loading -> {
                        _state.value = _state.value.copy(isLoading = true)
                    }
                    is ApiResult.Success -> {
                        _state.value = _state.value.copy(
                            isLoading = false,
                            categories = result.data,
                            error = null
                        )
                        // Load first category avatars by default
                        result.data.firstOrNull()?.let { category ->
                            loadAvatarsByCategory(category)
                        }
                    }
                    is ApiResult.Error -> {
                        _state.value = _state.value.copy(
                            isLoading = false,
                            error = result.message
                        )
                    }
                }
            }
        }
    }

    fun loadAvatarsByCategory(category: AvatarCategory) {
        viewModelScope.launch {
            _state.value = _state.value.copy(
                isLoading = true,
                selectedCategory = category,
                currentTab = AvatarTab.CATEGORIES,
                searchQuery = "",
                searchResults = emptyList()
            )

            avatarRepository.getAvatarsByCategory(category.id).collect { result ->
                when (result) {
                    is ApiResult.Loading -> {
                        _state.value = _state.value.copy(isLoading = true)
                    }
                    is ApiResult.Success -> {
                        _state.value = _state.value.copy(
                            isLoading = false,
                            avatars = result.data,
                            error = null
                        )
                    }
                    is ApiResult.Error -> {
                        _state.value = _state.value.copy(
                            isLoading = false,
                            error = result.message
                        )
                    }
                }
            }
        }
    }

    fun loadUserAvatarData(userId: Int) {
        viewModelScope.launch {
            avatarRepository.getUserAvatarData(userId).collect { result ->
                when (result) {
                    is ApiResult.Success -> {
                        _state.value = _state.value.copy(
                            userAvatarData = result.data
                        )
                        
                        // Load personality analysis if available
                        result.data.personalityAnalysis?.let { personality ->
                            _personalityInsights.value = generatePersonalityInsights(personality)
                        } ?: run {
                            loadPersonalityAnalysis(userId)
                        }
                    }
                    is ApiResult.Error -> {
                        _state.value = _state.value.copy(error = result.message)
                    }
                    else -> {}
                }
            }
        }
    }

    private fun loadPersonalityAnalysis(userId: Int) {
        viewModelScope.launch {
            avatarRepository.getPersonalityAnalysis(userId).collect { result ->
                when (result) {
                    is ApiResult.Success -> {
                        _personalityInsights.value = generatePersonalityInsights(result.data)
                    }
                    else -> {}
                }
            }
        }
    }

    fun updateSearchQuery(query: String) {
        _searchQuery.value = query
        _state.value = _state.value.copy(searchQuery = query)
        
        if (query.isBlank()) {
            _state.value = _state.value.copy(
                searchResults = emptyList(),
                isSearching = false
            )
        }
    }

    private fun performSearch(query: String) {
        viewModelScope.launch {
            _state.value = _state.value.copy(isSearching = true)
            
            val categoryId = _state.value.selectedCategory?.id
            avatarRepository.searchAvatars(query, categoryId).collect { result ->
                when (result) {
                    is ApiResult.Success -> {
                        _state.value = _state.value.copy(
                            isSearching = false,
                            searchResults = result.data.avatars,
                            error = null
                        )
                    }
                    is ApiResult.Error -> {
                        _state.value = _state.value.copy(
                            isSearching = false,
                            error = result.message
                        )
                    }
                    else -> {}
                }
            }
        }
    }

    fun selectAvatar(userId: Int, avatar: Avatar) {
        viewModelScope.launch {
            _state.value = _state.value.copy(isLoading = true)
            
            avatarRepository.setUserAvatar(userId, avatar.id).collect { result ->
                when (result) {
                    is ApiResult.Success -> {
                        _state.value = _state.value.copy(
                            isLoading = false,
                            userAvatarData = _state.value.userAvatarData?.copy(
                                currentAvatar = result.data
                            )
                        )
                        // Refresh user data to get updated stats
                        loadUserAvatarData(userId)
                    }
                    is ApiResult.Error -> {
                        _state.value = _state.value.copy(
                            isLoading = false,
                            error = result.message
                        )
                    }
                    else -> {}
                }
            }
        }
    }

    fun toggleFavorite(userId: Int, avatar: Avatar, isFavorite: Boolean) {
        viewModelScope.launch {
            avatarRepository.toggleAvatarFavorite(userId, avatar.id, isFavorite).collect { result ->
                when (result) {
                    is ApiResult.Success -> {
                        // Update local state
                        val updatedFavorites = if (isFavorite) {
                            (_state.value.userAvatarData?.favoriteAvatars ?: emptyList()) + result.data
                        } else {
                            (_state.value.userAvatarData?.favoriteAvatars ?: emptyList())
                                .filterNot { it.avatarId == avatar.id }
                        }
                        
                        _state.value = _state.value.copy(
                            userAvatarData = _state.value.userAvatarData?.copy(
                                favoriteAvatars = updatedFavorites
                            )
                        )
                    }
                    is ApiResult.Error -> {
                        _state.value = _state.value.copy(error = result.message)
                    }
                    else -> {}
                }
            }
        }
    }

    fun switchTab(tab: AvatarTab) {
        _state.value = _state.value.copy(currentTab = tab)
        
        when (tab) {
            AvatarTab.SEARCH -> {
                // Clear search when switching to search tab
                updateSearchQuery("")
            }
            AvatarTab.CATEGORIES -> {
                // Reload current category avatars
                _state.value.selectedCategory?.let { category ->
                    loadAvatarsByCategory(category)
                }
            }
            else -> {
                // For favorites, recent, personality tabs, data is already loaded
            }
        }
    }

    fun clearError() {
        _state.value = _state.value.copy(error = null)
    }

    private fun generatePersonalityInsights(personality: AvatarPersonality): List<PersonalityInsight> {
        return listOf(
            PersonalityInsight(
                type = personality.personalityType,
                title = PersonalityTypes.getDisplayName(personality.personalityType),
                description = PersonalityTypes.getDescription(personality.personalityType),
                percentage = personality.score,
                color = PersonalityTypes.getColor(personality.personalityType),
                traits = personality.traits
            )
        )
    }

    // Helper functions for UI state
    fun getCurrentAvatarEmoji(): String? {
        return _state.value.userAvatarData?.currentAvatar?.avatar?.emoji
    }

    fun isFavorite(avatarId: Int): Boolean {
        return _state.value.userAvatarData?.favoriteAvatars?.any { it.avatarId == avatarId } ?: false
    }

    fun getDisplayAvatars(): List<Avatar> {
        return when (_state.value.currentTab) {
            AvatarTab.SEARCH -> {
                if (_state.value.searchQuery.isNotBlank()) {
                    _state.value.searchResults
                } else {
                    emptyList()
                }
            }
            AvatarTab.FAVORITES -> {
                _state.value.userAvatarData?.favoriteAvatars?.mapNotNull { it.avatar } ?: emptyList()
            }
            AvatarTab.RECENT -> {
                _state.value.userAvatarData?.recentAvatars?.mapNotNull { it.avatar } ?: emptyList()
            }
            else -> _state.value.avatars
        }
    }

    fun refreshData(userId: Int) {
        loadCategories()
        loadUserAvatarData(userId)
    }
}