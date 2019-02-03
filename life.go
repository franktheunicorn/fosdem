package conwaysGameOfLife

import (
	"errors"
	"fmt"
	"strings"
)

var ErrUnmatchedDimensions = errors.New("dimensions don't match")

type Life interface {
	Tick()
	Board() string
}

type NaiveLife struct {
	board []string
	rows  int
	cols  int
}

func (l *NaiveLife) Tick() {
	newBoard := l.copyBoard()

	for i := 0; i < l.rows; i++ {
		for j := 0; j < l.cols; j++ {
			n := l.countNeighbors(i, j)
			if n < 2 || n > 3 {
				newBoard[i][j] = '.'
			}

			if n == 3 {
				newBoard[i][j] = 'x'
			}
		}
	}

	l.board = twoIntArrayToStringArray(newBoard)
}

func twoIntArrayToStringArray(arr [][]uint8) []string {
	s := make([]string, 0)
	for i := 0; i < len(arr); i++ {
		s = append(s, intArrayToString(arr[i]))
	}

	return s
}

func intArrayToString(arr []uint8) string {
	s := ""
	for j := 0; j < len(arr); j++ {
		s += fmt.Sprintf("%c", arr[j])
	}
	return s
}

func (l *NaiveLife) Board() string {
	return strings.Join(l.board, "\n")
}

func (l *NaiveLife) countNeighbors(x, y int) int {
	ans := 0
	for dx := -1; dx <= 1; dx++ {
		for dy := -1; dy <= 1; dy++ {
			if dx == 0 && dy == 0 {
				continue
			}

			nx := x + dx
			ny := y + dy

			if l.bounds(nx, ny) && l.board[nx][ny] == 'x' {
				ans++
			}
		}
	}

	return ans
}

func (l *NaiveLife) bounds(dx, dy int) bool {
	return dx >= 0 && dx < l.rows &&
		dy >= 0 && dy < l.cols
}

func (l *NaiveLife) copyBoard() [][]uint8 {
	cBoard := make([][]uint8, 0)
	for i := 0; i < l.rows; i++ {
		cBoard = append(cBoard, make([]uint8, 0))
		for j := 0; j < l.cols; j++ {
			cBoard[i] = append(cBoard[i], l.board[i][j])
		}
	}
	return cBoard
}

func (l *NaiveLife) PlayRounds(n int) {
	for i := 0; i < n; i++ {
		l.Tick()
	}
}

func NewNaiveLife(initialBoard string) (*NaiveLife, error) {
	width := -1
	board := make([]string, 0)
	for _, line := range strings.Split(initialBoard, "\n") {
		if line == "" {
			continue
		}

		if width == -1 {
			width = len(line)
		}

		if len(line) != width {
			return nil, ErrUnmatchedDimensions
		}
		board = append(board, line)
	}

	return &NaiveLife{board: board, rows: len(board), cols: width}, nil
}
