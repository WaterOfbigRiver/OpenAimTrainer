extends SceneTree

# 用法（项目根目录执行）：
# godot --headless --path . --script res://tools/build_translations.gd
#
# 把 assets/text/translations.csv 编译成 .translation 资源。
# 输出哪些语言完全由 CSV 表头决定（首行形如：key,en,es,zh_CN,…），
# 新增语言列时无需改脚本；产物路径固定为 assets/text/translations.<locale>.translation。

const CSV_PATH := "res://assets/text/translations.csv"
const OUTPUT_DIR := "res://assets/text/translations"
const OUTPUT_SUFFIX := ".translation"

func _initialize() -> void:
	var file := FileAccess.open(CSV_PATH, FileAccess.READ)
	if file == null:
		push_error("无法读取 CSV: " + CSV_PATH)
		quit(1)
		return
	var raw_lines := file.get_as_text().split("\n")
	file.close()

	var lines: Array[String] = []
	for line in raw_lines:
		if line.strip_edges() != "":
			lines.append(line)

	if lines.is_empty():
		push_error("CSV 为空")
		quit(1)
		return

	var header := _parse_csv_line(lines[0])
	# 第 0 列是 key，其余列都是 locale；按表头动态生成输出，避免遗漏新语言
	if header.size() < 2:
		push_error("CSV 表头至少需要 key 与一列 locale")
		quit(1)
		return
	var locales: Array[String] = []
	for i in range(1, header.size()):
		var locale := header[i].strip_edges()
		if locale == "":
			continue
		locales.append(locale)

	var column_of_locale := {}
	var outputs := {}
	for locale in locales:
		var column := header.find(locale)
		if column == -1:
			push_error("CSV 缺少列: " + locale)
			quit(1)
			return
		column_of_locale[locale] = column
		outputs[locale] = "%s.%s%s" % [OUTPUT_DIR, locale, OUTPUT_SUFFIX]

	var translations := {}
	for locale in locales:
		var translation := Translation.new()
		translation.locale = locale
		translations[locale] = translation

	var count := 0
	for i in range(1, lines.size()):
		var columns := _parse_csv_line(lines[i])
		if columns.is_empty() or columns[0] == "":
			continue
		var key := columns[0]
		for locale in locales:
			var column: int = column_of_locale[locale]
			var value := "" if column >= columns.size() else columns[column]
			translations[locale].add_message(key, value)
		count += 1

	for locale in locales:
		var error := ResourceSaver.save(translations[locale], outputs[locale])
		print("%-6s -> %s (err=%d)" % [locale, outputs[locale], error])

	print("导出完成：%d 条 × %d 语言" % [count, locales.size()])
	quit()


# 支持带引号、引号内逗号与 "" 转义的 CSV 行
func _parse_csv_line(line: String) -> PackedStringArray:
	var result := PackedStringArray()
	var current := ""
	var in_quotes := false
	var index := 0
	while index < line.length():
		var character := line[index]
		if character == "\"":
			if in_quotes and index + 1 < line.length() and line[index + 1] == "\"":
				current += "\""
				index += 1
			else:
				in_quotes = not in_quotes
		elif character == "," and not in_quotes:
			result.append(current)
			current = ""
		else:
			current += character
		index += 1
	result.append(current)
	return result
