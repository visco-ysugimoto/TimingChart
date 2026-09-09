import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/models/chart/chart_segment.dart';
import 'package:flutter_application_1/models/chart/timing_chart_annotation.dart';
import 'package:flutter_application_1/services/chart_segment_service.dart';

void main() {
  group('ChartSegmentService', () {
    int idSeq = 0;
    String nextId() => 'seg_${idSeq++}';

    setUp(() {
      idSeq = 0;
    });

    test('結合時に現在と追加分を2本のセグメントにする', () {
      final segments = ChartSegmentService.appendAfterConcat(
        currentSegments: const [],
        currentLength: 3,
        incomingSegments: const [],
        incomingLength: 2,
        currentLabel: 'A',
        incomingLabel: 'B',
        newId: nextId,
      );

      expect(segments, hasLength(2));
      expect(segments[0].label, 'A');
      expect(segments[0].startTimeIndex, 0);
      expect(segments[0].endTimeIndex, 3);
      expect(segments[1].label, 'B');
      expect(segments[1].startTimeIndex, 3);
      expect(segments[1].endTimeIndex, 5);
    });

    test('incoming にセグメントがあればオフセットして追加する', () {
      final incoming = [
        ChartSegment(
          id: 'in1',
          label: 'B1',
          startTimeIndex: 0,
          endTimeIndex: 2,
        ),
        ChartSegment(
          id: 'in2',
          label: 'B2',
          startTimeIndex: 2,
          endTimeIndex: 4,
        ),
      ];
      final segments = ChartSegmentService.appendAfterConcat(
        currentSegments: [
          const ChartSegment(
            id: 'cur',
            label: 'A',
            startTimeIndex: 0,
            endTimeIndex: 3,
          ),
        ],
        currentLength: 3,
        incomingSegments: incoming,
        incomingLength: 4,
        currentLabel: 'A',
        incomingLabel: 'B',
        newId: nextId,
      );

      expect(segments, hasLength(3));
      expect(segments[0].label, 'A');
      expect(segments[1].label, 'B1');
      expect(segments[1].startTimeIndex, 3);
      expect(segments[1].endTimeIndex, 5);
      expect(segments[2].label, 'B2');
      expect(segments[2].startTimeIndex, 5);
      expect(segments[2].endTimeIndex, 7);
    });

    test('並べ替えで波形スライスとコメント位置が入れ替わる', () {
      final mutation = ChartSegmentService.reorderSegments(
        signalValues: const [
          [1, 1, 1, 0, 0],
        ],
        signalNames: const ['IN1'],
        annotations: const [
          TimingChartAnnotation(
            id: 'c1',
            startTimeIndex: 0,
            endTimeIndex: 2,
            text: 'left',
          ),
          TimingChartAnnotation(
            id: 'c2',
            startTimeIndex: 3,
            endTimeIndex: 4,
            text: 'right',
          ),
        ],
        omissionIndices: const [4],
        stepDurationsMs: const [1, 1, 1, 2, 2],
        segments: const [
          ChartSegment(
            id: 'a',
            label: 'A',
            startTimeIndex: 0,
            endTimeIndex: 3,
          ),
          ChartSegment(
            id: 'b',
            label: 'B',
            startTimeIndex: 3,
            endTimeIndex: 5,
          ),
        ],
        fromIndex: 0,
        toIndex: 1,
      );

      expect(mutation, isNotNull);
      expect(mutation!.signalValues.single, [0, 0, 1, 1, 1]);
      expect(mutation.segments[0].label, 'B');
      expect(mutation.segments[0].startTimeIndex, 0);
      expect(mutation.segments[0].endTimeIndex, 2);
      expect(mutation.segments[1].label, 'A');
      expect(mutation.segments[1].startTimeIndex, 2);
      expect(mutation.segments[1].endTimeIndex, 5);
      expect(mutation.annotations[0].text, 'left');
      expect(mutation.annotations[0].startTimeIndex, 2);
      expect(mutation.annotations[1].text, 'right');
      expect(mutation.annotations[1].startTimeIndex, 0);
      expect(mutation.omissionIndices, [1]);
      expect(mutation.stepDurationsMs, [2, 2, 1, 1, 1]);
    });

    test('削除で対象区間の波形とコメントが消える', () {
      final mutation = ChartSegmentService.deleteSegment(
        signalValues: const [
          [1, 1, 0, 0, 1],
        ],
        signalNames: const ['IN1'],
        annotations: const [
          TimingChartAnnotation(
            id: 'keep',
            startTimeIndex: 0,
            endTimeIndex: 1,
            text: 'keep',
          ),
          TimingChartAnnotation(
            id: 'drop',
            startTimeIndex: 2,
            endTimeIndex: 3,
            text: 'drop',
          ),
          TimingChartAnnotation(
            id: 'shift',
            startTimeIndex: 4,
            endTimeIndex: 4,
            text: 'shift',
          ),
        ],
        omissionIndices: const [2, 4],
        stepDurationsMs: const [1, 1, 3, 3, 5],
        segments: const [
          ChartSegment(
            id: 'a',
            label: 'A',
            startTimeIndex: 0,
            endTimeIndex: 2,
          ),
          ChartSegment(
            id: 'b',
            label: 'B',
            startTimeIndex: 2,
            endTimeIndex: 4,
          ),
          ChartSegment(
            id: 'c',
            label: 'C',
            startTimeIndex: 4,
            endTimeIndex: 5,
          ),
        ],
        segmentId: 'b',
      );

      expect(mutation, isNotNull);
      expect(mutation!.signalValues.single, [1, 1, 1]);
      expect(mutation.segments.map((s) => s.label), ['A', 'C']);
      expect(mutation.segments[1].startTimeIndex, 2);
      expect(mutation.segments[1].endTimeIndex, 3);
      expect(mutation.annotations.map((a) => a.text), ['keep', 'shift']);
      expect(mutation.annotations.last.startTimeIndex, 2);
      expect(mutation.omissionIndices, [2]);
      expect(mutation.stepDurationsMs, [1, 1, 5]);
    });

    test('列削除に合わせてセグメント境界が縮む', () {
      final updated = ChartSegmentService.shiftAfterDelete(
        segments: const [
          ChartSegment(
            id: 'a',
            label: 'A',
            startTimeIndex: 0,
            endTimeIndex: 4,
          ),
          ChartSegment(
            id: 'b',
            label: 'B',
            startTimeIndex: 4,
            endTimeIndex: 8,
          ),
        ],
        deleteStart: 2,
        deleteEnd: 6,
      );
      expect(updated, hasLength(2));
      expect(updated[0].startTimeIndex, 0);
      expect(updated[0].endTimeIndex, 2);
      expect(updated[1].startTimeIndex, 2);
      expect(updated[1].endTimeIndex, 4);
    });
  });
}
