extends RefCounted

var id := 0
var name := ""
var owner := -1
var soldiers := 0
var supplied := true
var recovering := 0
var unrest := 0
var neighbors: Array[int] = []
var cells: Array[Vector2i] = []
var center := Vector2i.ZERO
