package model

// SearchQuery represents a search request with pagination.
type SearchQuery struct {
	Query  string
	Type   string // "hashtag" or "user"
	Limit  int
	Offset int
}

// SearchResult wraps search results for both hashtag and user searches.
type SearchResult struct {
	Messages []Message       `json:"messages,omitempty"`
	Users    []UserSummary   `json:"users,omitempty"`
	Hashtags []HashtagResult `json:"hashtags,omitempty"`
	Total    int             `json:"total"`
}

// UserSummary is a lightweight user representation for search results.
type UserSummary struct {
	ID       string `json:"id"`
	Username string `json:"username"`
}

// HashtagResult represents a popular hashtag with its usage count.
type HashtagResult struct {
	Tag   string `json:"tag"`
	Count int    `json:"count"`
}
