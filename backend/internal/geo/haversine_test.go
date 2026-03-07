package geo

import (
	"math"
	"testing"
)

func TestDistanceMeters(t *testing.T) {
	tests := []struct {
		name     string
		lat1     float64
		lng1     float64
		lat2     float64
		lng2     float64
		expected float64
		delta    float64
	}{
		{
			name:     "Tour Eiffel -> Arc de Triomphe",
			lat1:     48.8584, lng1: 2.2945,
			lat2:     48.8738, lng2: 2.2950,
			expected: 1712,
			delta:    50,
		},
		{
			name:     "meme point",
			lat1:     48.8566, lng1: 2.3522,
			lat2:     48.8566, lng2: 2.3522,
			expected: 0,
			delta:    0.01,
		},
		{
			name:     "Paris -> Lyon",
			lat1:     48.8566, lng1: 2.3522,
			lat2:     45.7640, lng2: 4.8357,
			expected: 392_000,
			delta:    5000,
		},
		{
			name:     "poles opposes",
			lat1:     90, lng1: 0,
			lat2:     -90, lng2: 0,
			expected: math.Pi * earthRadiusMeters,
			delta:    1,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := DistanceMeters(tt.lat1, tt.lng1, tt.lat2, tt.lng2)
			if math.Abs(got-tt.expected) > tt.delta {
				t.Errorf("DistanceMeters() = %.1f, attendu ~%.1f (delta %.1f)", got, tt.expected, tt.delta)
			}
		})
	}
}

func BenchmarkDistanceMeters(b *testing.B) {
	for i := 0; i < b.N; i++ {
		DistanceMeters(48.8584, 2.2945, 48.8738, 2.2950)
	}
}
