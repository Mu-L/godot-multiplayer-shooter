extends Node

var obj: Object
var node: Node2D

func _ready() -> void:
	var div: String = "=========="
	print(div, "Before construct", div)
	# 未赋值打印
	if obj:
		print("if obj: true")
	else:
		print("if obj: false")
		
	if node:
		print("if node: true")
	else:
		print("if node: false")
	# 未赋值判空
	print("obj == null: ", "true" if obj == null else "false")
	print("node == null: ", "true" if node == null else "false")
	# 赋值
	obj = Object.new()
	node = Node2D.new()
	# 释放
	obj.free()
	node.free()
	print(div, "After Deconstruct", div)
	# 再次打印
	if obj:
		print("if obj: true")
	else:
		print("if obj: false")
	if node:
		print("if node: true")
	else:
		print("if node: false")
	print("obj == null: ", "true" if obj == null else "false")
	print("node == null: ", "true" if node == null else "false")
