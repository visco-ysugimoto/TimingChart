# TimingChart 処理フローチャート

このドキュメントは `timing_chart.dart` の主要な処理フローをフローチャートで説明します。

## 1. ウィジェット初期化フロー

```mermaid
flowchart TD
    A[TimingChart Widget Created] --> B[initState Called]
    B --> C[Initialize _idSignalNames from widget.initialSignalNames]
    C --> D[Initialize signalNames from _idSignalNames]
    D --> E[Call _translateNames]
    E --> F[Register Language Listener]
    F --> G[Register Keyboard Handler]
    G --> H{Controller Provided?}
    H -->|Yes| I[Use Provided Controller]
    H -->|No| J[Create New TimingChartController]
    I --> K[Initialize signals from controller]
    J --> K
    K --> L[Initialize annotations from controller]
    L --> M[Register Controller Listener]
    M --> N[Widget Ready]
    
    style A fill:#e1f5ff
    style N fill:#c8e6c9
```

## 2. ビルド・レイアウト計算フロー

```mermaid
flowchart TD
    A[build Method Called] --> B{isEditingMode?}
    B -->|Yes| C[Listener + LayoutBuilder]
    B -->|No| D[KeyboardListener + Listener + LayoutBuilder]
    C --> E[Get Settings from Provider]
    D --> E
    E --> F[Call _calculateLayoutData]
    F --> G[Calculate maxLen from signals]
    G --> H[Calculate visibleIndexes]
    H --> I[Calculate availableWidth]
    I --> J[Get durationsForLayout]
    J --> K[Calculate totalSteps]
    K --> L[Calculate baseCellWidth]
    L --> M[Calculate minCellWidthForFullView]
    M --> N[Calculate maxCellWidthAllowed]
    N --> O[Calculate zoom factors]
    O --> P[Calculate effectiveZoomFactor]
    P --> Q[Calculate cellWidth and cellHeight]
    Q --> R[Calculate totalWidth and totalHeight]
    R --> S[Calculate commentAreaHeight]
    S --> T[Create _ChartLayoutData]
    T --> U[Call _buildChartContent]
    U --> V[Update State Variables]
    V --> W[Build Visible Data Lists]
    W --> X[Build Widget Tree]
    X --> Y[Render Chart]
    
    style A fill:#e1f5ff
    style Y fill:#c8e6c9
```

## 3. ユーザータップ処理フロー

```mermaid
flowchart TD
    A[User Taps Chart] --> B[_handleTap Called]
    B --> C[Calculate chartLocalPos]
    C --> D[Calculate adjustedPos]
    D --> E{Annotation Hit?}
    E -->|Yes| F[Set _selectedAnnotationId]
    F --> G[Clear Selection]
    G --> Z[End]
    E -->|No| H{In Label Area?}
    H -->|Yes| I[Get Signal Index from Y]
    I --> J{Valid Row?}
    J -->|Yes| K{Already Selected?}
    K -->|Yes| L[Clear Selection]
    K -->|No| M[Select Entire Row]
    L --> Z
    M --> Z
    J -->|No| Z
    H -->|No| N[Get Signal Index from Y]
    N --> O[Get Time Index from X]
    O --> P{Valid Indices?}
    P -->|No| Q[Clear Selection]
    Q --> Z
    P -->|Yes| R{Has Valid Selection?}
    R -->|Yes| S{Click in Selection?}
    S -->|Yes| T[_toggleSignalsInSelection]
    S -->|No| U[Clear Selection]
    U --> V[_toggleSingleSignal]
    T --> Z
    V --> Z
    R -->|No| W[_toggleSingleSignal]
    W --> Z
    
    style A fill:#fff9c4
    style Z fill:#c8e6c9
```

## 4. ドラッグ処理フロー（選択範囲作成）

```mermaid
flowchart TD
    A[User Starts Drag] --> B[_onPanStart Called]
    B --> C[Get Local Position]
    C --> D{Annotation Hit?}
    D -->|Yes| E[Set _draggingAnnotationId]
    E --> F[Set Drag Start Position]
    F --> Z[End - Annotation Drag]
    D -->|No| G{In Label Area?}
    G -->|Yes| H[Set _isLabelDrag = true]
    H --> I[Set _labelDragStartRow]
    I --> Z2[End - Label Drag]
    G -->|No| J[Get Signal Index]
    J --> K[Get Time Index]
    K --> L{Valid Indices?}
    L -->|No| M[Clear Selection]
    M --> Z3[End]
    L -->|Yes| N[Set Selection Start]
    N --> O[_onPanUpdate Called]
    O --> P[Get Current Signal Index]
    P --> Q[Get Current Time Index]
    Q --> R[Clamp Indices]
    R --> S[Update Selection End]
    S --> T{Still Dragging?}
    T -->|Yes| O
    T -->|No| U[_onPanEnd Called]
    U --> V{Start == End?}
    V -->|Yes| W[Clear Selection]
    V -->|No| X[Keep Selection]
    W --> Z3
    X --> Z3
    
    style A fill:#fff9c4
    style Z fill:#c8e6c9
    style Z2 fill:#c8e6c9
    style Z3 fill:#c8e6c9
```

## 5. 信号編集フロー

```mermaid
flowchart TD
    A[User Edits Signal] --> B{Edit Type?}
    B -->|Toggle Single| C[_toggleSingleSignal]
    B -->|Toggle Selection| D[_toggleSignalsInSelection]
    B -->|Set Value| E[_setSignalsInSelection]
    C --> F[Get Original Row Index]
    F --> G[Toggle Signal Value 0↔1]
    G --> H[_commitSignalsFromChartEdit]
    D --> I[Get Selection Range]
    I --> J[Iterate Through Selection]
    J --> K[Toggle Each Signal Value]
    K --> H
    E --> L[Get Selection Range]
    L --> M[Iterate Through Selection]
    M --> N[Set Each Signal to Value]
    N --> H
    H --> O[_controller?.setSignals]
    O --> P[_notifySignalsChanged]
    P --> Q[Call onSignalsChanged Callback]
    Q --> R[Update UI]
    
    style A fill:#fff9c4
    style R fill:#c8e6c9
```

## 6. ズーム操作フロー

```mermaid
flowchart TD
    A[Zoom Operation] --> B{Zoom Type?}
    B -->|Zoom In| C[_zoomIn]
    B -->|Zoom Out| D[_zoomOut]
    B -->|Reset| E[_resetZoom]
    B -->|Fit Selection| F[_zoomToSelectionFit]
    B -->|Mouse Wheel| G[_handlePointerSignal]
    C --> H[Calculate Next Zoom Factor]
    H --> I[Clamp to Max Zoom]
    I --> J[Update _zoomFactor]
    D --> K[Calculate Next Zoom Factor]
    K --> L[Clamp to Min Zoom]
    L --> J
    E --> M[Set Zoom to 1.0 or Min]
    M --> J
    F --> N{Has Valid Selection?}
    N -->|No| Z[End]
    N -->|Yes| O[Calculate Selection Width]
    O --> P[Calculate Target Zoom]
    P --> Q[Update _zoomFactor]
    Q --> R[Calculate Scroll Position]
    R --> S[Apply Scroll Correction]
    S --> Z
    G --> T{Modifier Pressed?}
    T -->|No| Z
    T -->|Yes| U[Get Scroll Delta]
    U --> V{Delta < 0?}
    V -->|Yes| C
    V -->|No| D
    J --> W[setState]
    W --> X[Trigger Rebuild]
    X --> Y[Recalculate Layout]
    Y --> Z
    
    style A fill:#fff9c4
    style Z fill:#c8e6c9
```

## 7. コンテキストメニュー処理フロー

```mermaid
flowchart TD
    A[Right Click] --> B[_showContextMenu Called]
    B --> C[Calculate Click Position]
    C --> D[Get Clicked Time Index]
    D --> E[Get Clicked Signal Index]
    E --> F{Annotation Hit?}
    F -->|Yes| G[Build Annotation Menu]
    G --> H[Show Menu]
    H --> I{Menu Action?}
    I -->|editComment| J[_editComment]
    I -->|deleteComment| K[_deleteComment]
    I -->|toggleArrowHorizontal| L[Toggle Arrow Direction]
    I -->|setArrowTipToRow| M[_setAnnotationArrowToSignal]
    F -->|No| N[Build Chart Menu]
    N --> O[Show Menu]
    O --> P{Menu Action?}
    P -->|insert| Q[_insertZerosToSelection]
    P -->|duplicate| R[_duplicateRange]
    P -->|selectAll| S[_selectAllSignals]
    P -->|delete| T[_deleteRange]
    P -->|deleteColumns| U[_deleteColumns]
    P -->|addComment| V{Has Selection?}
    V -->|Yes| W[_showAddRangeCommentDialog]
    V -->|No| X[_showAddCommentDialog]
    P -->|omit| Y[_toggleOmissionTime]
    J --> Z[End]
    K --> Z
    L --> Z
    M --> Z
    Q --> Z
    R --> Z
    S --> Z
    T --> Z
    U --> Z
    W --> Z
    X --> Z
    Y --> Z
    
    style A fill:#fff9c4
    style Z fill:#c8e6c9
```

## 8. レンダリングフロー（CustomPainter）

```mermaid
flowchart TD
    A[paint Method Called] --> B[Save Canvas State]
    B --> C[Translate to Chart Margin]
    C --> D[Draw Label Mask]
    D --> E{Dragging Label?}
    E -->|Yes| F[Draw Drag Highlight]
    E -->|No| G[Continue]
    F --> G
    G --> H[_gridManager.drawGridLines]
    H --> I[_gridManager.drawHighlightedLines]
    I --> J[Clip to Wave Area]
    J --> K[_signalsManager.drawSignalWaveforms]
    K --> L[_drawOmissionLines]
    L --> M[_signalsManager.drawSelectionHighlight]
    M --> N[_annotationsManager.drawAnnotations]
    N --> O[_gridManager.drawTimeLabels]
    O --> P[Update _annotationHitRects]
    P --> Q[Restore Canvas State]
    Q --> R[Done]
    
    style A fill:#e1f5ff
    style R fill:#c8e6c9
```

## 9. コントローラー更新フロー

```mermaid
flowchart TD
    A[Controller State Changed] --> B[_controllerListener Called]
    B --> C{Mounted?}
    C -->|No| Z[End]
    C -->|Yes| D[Get Controller Signals]
    D --> E[Get Controller Names]
    E --> F[Get Controller Annotations]
    F --> G[Get Controller Omission Indices]
    G --> H{Names Changed?}
    H -->|Yes| I[Update _idSignalNames]
    I --> J[Call _translateNames]
    H -->|No| K[Continue]
    J --> K
    K --> L[setState]
    L --> M[Update signals]
    M --> N[Update annotations]
    N --> O[Update _omissionTimeIndices]
    O --> P[_forceRepaint]
    P --> Q{Grid Reset?}
    Q -->|Yes| R[resetGridAdjustments]
    Q -->|No| S[Continue]
    R --> S
    S --> T{Grid Recompute?}
    T -->|Yes| U[setState]
    T -->|No| V[Continue]
    U --> V
    V --> W[Ensure Step Durations Length]
    W --> Z
    
    style A fill:#fff9c4
    style Z fill:#c8e6c9
```

## 10. 信号行の並び替えフロー

```mermaid
flowchart TD
    A[User Drags Label] --> B[_onPanStart - Label Area]
    B --> C[Set _isLabelDrag = true]
    C --> D[Set _labelDragStartRow]
    D --> E[_onPanUpdate]
    E --> F[Get Current Signal Index]
    F --> G{Row Changed?}
    G -->|Yes| H[Update _labelDragCurrentRow]
    G -->|No| I[Continue]
    H --> J{Still Dragging?}
    I --> J
    J -->|Yes| E
    J -->|No| K[_onPanEnd]
    K --> L{Start != Current?}
    L -->|No| M[Clear Drag State]
    L -->|Yes| N[_reorderSignalRows]
    M --> Z[End]
    N --> O{From < To?}
    O -->|Yes| P[Move Down Loop]
    O -->|No| Q[Move Up Loop]
    P --> R[_moveSignal]
    Q --> R
    R --> S[Swap Signals]
    S --> T[Swap Signal Names]
    T --> U[Swap Signal Types]
    U --> V[Swap Port Numbers]
    V --> W[Swap IO Sources]
    W --> X[Swap ID Names]
    X --> Y[_forceRepaint]
    Y --> Z
    
    style A fill:#fff9c4
    style Z fill:#c8e6c9
```

## 凡例

- **青い背景**: 開始ノード
- **緑の背景**: 終了ノード
- **黄色の背景**: ユーザーアクション
- **ひし形**: 条件分岐
- **四角形**: 処理ステップ

## 主要な処理の説明

### 初期化
ウィジェット作成時に信号データ、アノテーション、コントローラーを初期化し、リスナーを登録します。

### レイアウト計算
制約と設定に基づいて、セルサイズ、ズーム係数、可視インデックスなどを計算します。

### ユーザーインタラクション
タップ、ドラッグ、ズームなどの操作を処理し、選択範囲の作成や信号の編集を行います。

### レンダリング
CustomPainterを使用して、グリッド、信号波形、アノテーション、選択範囲などを描画します。

### コントローラー更新
外部からのデータ変更を検知し、状態を更新してUIを再描画します。

