import pathlib

path = pathlib.Path("lib/widgets/chart/timing_chart.dart")
data = path.read_bytes()
old = b"    if (!listEquals(widget.initialSignalNames, oldWidget.initialSignalNames) ||\r\n"
if old not in data:
    raise SystemExit('if line not found')
new = b"    final bool namesChanged =\r\n        !listEquals(widget.initialSignalNames, oldWidget.initialSignalNames);\r\n    if (namesChanged ||\r\n"
data = data.replace(old, new, 1)
path.write_bytes(data)
