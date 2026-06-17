import 'dart:async';
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/pawntrack_models.dart';
import '../services/pawntrack_forecast_ai_service.dart';
import '../widgets/stat_card.dart';

class ForecastScreen extends StatefulWidget {
  const ForecastScreen({super.key, required this.model, this.aiService});

  final PawnTrackModel model;
  final PawnTrackForecastAiService? aiService;

  @override
  State<ForecastScreen> createState() => _ForecastScreenState();
}

class _ForecastScreenState extends State<ForecastScreen> {
  late final PawnTrackForecastAiService _aiService;
  late _ForecastSnapshot _snapshot;
  late String _forecastText;
  String _forecastStatus = 'Local projection ready';
  bool _loadingAi = false;

  @override
  void initState() {
    super.initState();
    _aiService = widget.aiService ?? PawnTrackForecastAiService();
    _snapshot = _ForecastSnapshot.fromModel(widget.model);
    _forecastText = _localForecastText(_snapshot);
    unawaited(_refreshAiForecast());
  }

  @override
  void didUpdateWidget(covariant ForecastScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.model != widget.model) {
      _snapshot = _ForecastSnapshot.fromModel(widget.model);
      _forecastText = _localForecastText(_snapshot);
      _forecastStatus = 'Local projection refreshed';
      unawaited(_refreshAiForecast());
    }
  }

  Future<void> _refreshAiForecast() async {
    setState(() {
      _loadingAi = true;
      _forecastStatus = 'Checking Firebase AI Logic';
    });
    try {
      final result = await _aiService.generateOperationalForecast(
          widget.model, _snapshot.toPromptContext());
      if (!mounted) return;
      setState(() {
        _forecastText = result;
        _forecastStatus = 'Firebase AI Logic forecast';
        _loadingAi = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _forecastText = _localForecastText(_snapshot);
        _forecastStatus = 'Local fallback projection';
        _loadingAi = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _ForecastHeader(
          status: _forecastStatus,
          loading: _loadingAi,
          onRefresh: _loadingAi ? null : _refreshAiForecast,
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            StatCard(
                label: 'Due today',
                value: moneyFormat.format(snapshot.todayScheduled),
                tone: Colors.red),
            StatCard(
                label: '7-day likely cash',
                value: moneyFormat.format(snapshot.next7Likely),
                tone: Colors.green),
            StatCard(
                label: '30-day likely cash',
                value: moneyFormat.format(snapshot.next30Likely),
                tone: Colors.indigo),
            StatCard(
                label: '90-day scheduled',
                value: moneyFormat.format(snapshot.next90Scheduled),
                tone: Colors.blue),
            StatCard(
                label: 'Cash at risk 30d',
                value: moneyFormat.format(snapshot.cashAtRisk30),
                tone: Colors.deepOrange),
            StatCard(
                label: 'Overdue exposure',
                value: moneyFormat.format(snapshot.overdueExposure),
                tone: Colors.redAccent),
            StatCard(
                label: 'High-risk exposure',
                value: moneyFormat.format(snapshot.highRiskExposure),
                tone: Colors.orange),
            StatCard(
                label: 'Collection confidence',
                value: _percent(snapshot.baseCollectionRate),
                tone: Colors.teal),
            StatCard(
                label: 'Inventory value',
                value: moneyFormat.format(snapshot.inventoryValue),
                tone: Colors.blueGrey),
            StatCard(
                label: 'Slow-moving stock',
                value: moneyFormat.format(snapshot.slowMovingValue),
                tone: Colors.brown),
            StatCard(
                label: 'Discount candidates',
                value: '${snapshot.discountCandidateCount}',
                tone: Colors.purple),
            StatCard(
                label: 'Expected net profit',
                value: moneyFormat.format(snapshot.expectedNetProfit),
                tone: Colors.lightGreen),
          ].map((card) => SizedBox(width: 210, child: card)).toList(),
        ),
        const SizedBox(height: 18),
        _Panel(
          title: 'AI Forecast',
          child: _AiForecastBody(
            status: _forecastStatus,
            loading: _loadingAi,
            text: _forecastText,
            onRefresh: _loadingAi ? null : _refreshAiForecast,
          ),
        ),
        const SizedBox(height: 18),
        _TwoColumn(
          left: _Panel(
            title: 'Scheduled vs Likely Cash',
            child: _CashBucketChart(buckets: snapshot.cashBuckets),
          ),
          right: _Panel(
            title: '14-Day Collection Line',
            child: _DailyCashLineChart(rows: snapshot.dailyProjections),
          ),
        ),
        const SizedBox(height: 18),
        _TwoColumn(
          left: _Panel(
            title: 'Open Exposure by Risk',
            child: _RiskExposureChart(bands: snapshot.riskExposure),
          ),
          right: _Panel(
            title: 'Inventory Liquidity Mix',
            child: _InventoryLiquidityChart(slices: snapshot.inventorySlices),
          ),
        ),
        const SizedBox(height: 18),
        _TwoColumn(
          left: _Panel(
            title: 'Collection Priorities',
            child: _PriorityLoanList(loans: snapshot.collectionPriorities),
          ),
          right: _Panel(
            title: 'Inventory Moves',
            child: _InventoryActionList(items: snapshot.inventoryActions),
          ),
        ),
        const SizedBox(height: 18),
        _Panel(
          title: 'Control Points',
          child: _ControlPointGrid(snapshot: snapshot),
        ),
      ],
    );
  }
}

class _ForecastSnapshot {
  const _ForecastSnapshot({
    required this.cashBuckets,
    required this.dailyProjections,
    required this.riskExposure,
    required this.inventorySlices,
    required this.collectionPriorities,
    required this.inventoryActions,
    required this.baseCollectionRate,
    required this.floorCollectionRate,
    required this.stretchCollectionRate,
    required this.todayScheduled,
    required this.next7Scheduled,
    required this.next7Likely,
    required this.next30Scheduled,
    required this.next30Likely,
    required this.next90Scheduled,
    required this.cashAtRisk30,
    required this.overdueExposure,
    required this.highRiskExposure,
    required this.inventoryValue,
    required this.slowMovingValue,
    required this.discountCandidateCount,
    required this.expectedNetProfit,
    required this.openLoanCount,
    required this.averageDailyLikely,
    required this.liquidationValue,
  });

  final List<_CashForecastBucket> cashBuckets;
  final List<_DailyProjection> dailyProjections;
  final List<_RiskExposureBand> riskExposure;
  final List<_InventorySlice> inventorySlices;
  final List<LoanRecord> collectionPriorities;
  final List<InventoryRecord> inventoryActions;
  final double baseCollectionRate;
  final double floorCollectionRate;
  final double stretchCollectionRate;
  final double todayScheduled;
  final double next7Scheduled;
  final double next7Likely;
  final double next30Scheduled;
  final double next30Likely;
  final double next90Scheduled;
  final double cashAtRisk30;
  final double overdueExposure;
  final double highRiskExposure;
  final double inventoryValue;
  final double slowMovingValue;
  final int discountCandidateCount;
  final double expectedNetProfit;
  final int openLoanCount;
  final double averageDailyLikely;
  final double liquidationValue;

  factory _ForecastSnapshot.fromModel(PawnTrackModel model) {
    final openLoans = model.loans.where((loan) => loan.remaining > 0).toList();
    final remaining = model.remaining;
    final highRiskLoans =
        openLoans.where((loan) => loan.riskScore >= 70).toList();
    final highRiskExposure =
        highRiskLoans.fold(0.0, (sum, loan) => sum + loan.remaining);
    final overdueExposure = model.overdueAmount;
    final highRiskShare = remaining == 0 ? 0.0 : highRiskExposure / remaining;
    final overdueShare = remaining == 0 ? 0.0 : overdueExposure / remaining;
    final historicalRate = _clampDouble(model.collectionRate, 0, 1);
    final baseCollectionRate = _clampDouble(
        .3 +
            (historicalRate * .52) -
            (highRiskShare * .12) -
            (overdueShare * .1),
        .2,
        .76);
    final floorCollectionRate = _clampDouble(
        baseCollectionRate - .18 - (highRiskShare * .06), .08, .58);
    final stretchCollectionRate =
        _clampDouble(baseCollectionRate + .16, .28, .9);

    final cashBuckets = [
      _buildBucket('Today', openLoans, 0, 0, baseCollectionRate,
          floorCollectionRate, stretchCollectionRate, .96),
      _buildBucket('7 days', openLoans, 0, 7, baseCollectionRate,
          floorCollectionRate, stretchCollectionRate, .9),
      _buildBucket('Next week', openLoans, 8, 14, baseCollectionRate,
          floorCollectionRate, stretchCollectionRate, .84),
      _buildBucket('30 days', openLoans, 0, 30, baseCollectionRate,
          floorCollectionRate, stretchCollectionRate, .78),
      _buildBucket('90 days', openLoans, 0, 90, baseCollectionRate,
          floorCollectionRate, stretchCollectionRate, .66),
    ];

    final dailyProjections = [
      for (var day = 0; day < 14; day++)
        _buildDailyProjection(openLoans, day, baseCollectionRate)
    ];

    final lowRisk = _sumWhere(
        openLoans, (loan) => loan.riskScore < 40, (loan) => loan.remaining);
    final mediumRisk = _sumWhere(
        openLoans,
        (loan) => loan.riskScore >= 40 && loan.riskScore < 70,
        (loan) => loan.remaining);
    final highRisk = _sumWhere(
        openLoans, (loan) => loan.riskScore >= 70, (loan) => loan.remaining);
    final riskExposure = [
      _RiskExposureBand('Low', lowRisk, Colors.green),
      _RiskExposureBand('Medium', mediumRisk, Colors.orange),
      _RiskExposureBand('High', highRisk, Colors.red),
    ];

    final categoryRows = model.byCategory;
    final inventorySlices = <_InventorySlice>[];
    final topCategories = categoryRows.take(4).toList();
    for (var i = 0; i < topCategories.length; i++) {
      inventorySlices.add(_InventorySlice(
        topCategories[i].name,
        topCategories[i].value,
        _sliceColors[i % _sliceColors.length],
      ));
    }
    final otherValue =
        categoryRows.skip(4).fold(0.0, (sum, row) => sum + row.value);
    if (otherValue > 0) {
      inventorySlices.add(_InventorySlice('Other', otherValue, Colors.grey));
    }

    final collectionPriorities = [...openLoans]
      ..sort((a, b) => _loanPriorityScore(b).compareTo(_loanPriorityScore(a)));

    final inventoryActions = [...model.availableInventory]..sort(
        (a, b) => _inventoryActionScore(b).compareTo(_inventoryActionScore(a)));

    final slowMoving = model.availableInventory
        .where((item) => item.age == null || item.age! >= 21)
        .toList();
    final slowMovingValue =
        slowMoving.fold(0.0, (sum, item) => sum + item.value);
    final liquidationValue = model.availableInventory.fold(0.0, (sum, item) {
      final age = item.age ?? 31;
      final rate = age >= 45
          ? .72
          : age >= 21
              ? .8
              : .88;
      return sum + (item.value * rate);
    });

    final next7 = cashBuckets[1];
    final next30 = cashBuckets[3];
    final next90 = cashBuckets[4];
    final dailyLikely =
        dailyProjections.fold(0.0, (sum, row) => sum + row.likelyCollection);

    return _ForecastSnapshot(
      cashBuckets: cashBuckets,
      dailyProjections: dailyProjections,
      riskExposure: riskExposure,
      inventorySlices: inventorySlices,
      collectionPriorities: collectionPriorities.take(10).toList(),
      inventoryActions: inventoryActions.take(10).toList(),
      baseCollectionRate: baseCollectionRate,
      floorCollectionRate: floorCollectionRate,
      stretchCollectionRate: stretchCollectionRate,
      todayScheduled: cashBuckets.first.scheduled,
      next7Scheduled: next7.scheduled,
      next7Likely: next7.likely,
      next30Scheduled: next30.scheduled,
      next30Likely: next30.likely,
      next90Scheduled: next90.scheduled,
      cashAtRisk30: math.max(0, next30.scheduled - next30.likely),
      overdueExposure: overdueExposure,
      highRiskExposure: highRiskExposure,
      inventoryValue: model.inventoryValue,
      slowMovingValue: slowMovingValue,
      discountCandidateCount: model.discountItems.length,
      expectedNetProfit: model.expectedNetProfit,
      openLoanCount: openLoans.length,
      averageDailyLikely: dailyLikely / 14,
      liquidationValue: liquidationValue,
    );
  }

  Map<String, Object?> toPromptContext() {
    return {
      'generatedForDate': dateInputValue(today),
      'collectionRates': {
        'floor': floorCollectionRate,
        'base': baseCollectionRate,
        'stretch': stretchCollectionRate,
      },
      'kpis': {
        'todayScheduled': todayScheduled,
        'next7Scheduled': next7Scheduled,
        'next7Likely': next7Likely,
        'next30Scheduled': next30Scheduled,
        'next30Likely': next30Likely,
        'next90Scheduled': next90Scheduled,
        'cashAtRisk30': cashAtRisk30,
        'overdueExposure': overdueExposure,
        'highRiskExposure': highRiskExposure,
        'inventoryValue': inventoryValue,
        'slowMovingValue': slowMovingValue,
        'discountCandidateCount': discountCandidateCount,
        'expectedNetProfit': expectedNetProfit,
        'openLoanCount': openLoanCount,
        'averageDailyLikely': averageDailyLikely,
        'liquidationValue': liquidationValue,
      },
      'cashBuckets': cashBuckets.map((bucket) => bucket.toJson()).toList(),
      'daily14': dailyProjections.map((row) => row.toJson()).toList(),
      'riskExposure': riskExposure.map((band) => band.toJson()).toList(),
      'collectionPriorities': collectionPriorities
          .take(8)
          .map((loan) => {
                'client': loan.client,
                'item': loan.item,
                'remaining': loan.remaining,
                'dueDate': dateInputValue(loan.dueDate),
                'daysOverdue': loan.overdueDays,
                'riskScore': loan.riskScore,
                'riskBand': loan.risk.label,
              })
          .toList(),
      'inventoryActions': inventoryActions
          .take(8)
          .map((item) => {
                'product': item.product,
                'category': item.category,
                'listedAmount': item.value,
                'ageDays': item.age,
                'daysHeld': item.daysHeld,
              })
          .toList(),
    };
  }
}

class _CashForecastBucket {
  const _CashForecastBucket({
    required this.label,
    required this.scheduled,
    required this.floor,
    required this.likely,
    required this.stretch,
  });

  final String label;
  final double scheduled;
  final double floor;
  final double likely;
  final double stretch;

  Map<String, Object?> toJson() => {
        'label': label,
        'scheduled': scheduled,
        'floor': floor,
        'likely': likely,
        'stretch': stretch,
      };
}

class _DailyProjection {
  const _DailyProjection({
    required this.label,
    required this.date,
    required this.scheduled,
    required this.likelyCollection,
  });

  final String label;
  final DateTime date;
  final double scheduled;
  final double likelyCollection;

  Map<String, Object?> toJson() => {
        'date': dateInputValue(date),
        'scheduled': scheduled,
        'likelyCollection': likelyCollection,
      };
}

class _RiskExposureBand {
  const _RiskExposureBand(this.label, this.value, this.color);

  final String label;
  final double value;
  final Color color;

  Map<String, Object?> toJson() => {'label': label, 'value': value};
}

class _InventorySlice {
  const _InventorySlice(this.label, this.value, this.color);

  final String label;
  final double value;
  final Color color;
}

class _ForecastHeader extends StatelessWidget {
  const _ForecastHeader({
    required this.status,
    required this.loading,
    required this.onRefresh,
  });

  final String status;
  final bool loading;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 10,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Forecast',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text('Daily cash, collections, risk, and inventory outlook',
                style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _StatusPill(status: status, loading: loading),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              tooltip: 'Refresh forecast',
              onPressed: onRefresh,
              icon: const Icon(Icons.auto_awesome),
            ),
          ],
        ),
      ],
    );
  }
}

class _AiForecastBody extends StatelessWidget {
  const _AiForecastBody({
    required this.status,
    required this.loading,
    required this.text,
    required this.onRefresh,
  });

  final String status;
  final bool loading;
  final String text;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _StatusPill(status: status, loading: loading),
            const Spacer(),
            FilledButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh),
              label: Text(loading ? 'Running' : 'Run AI'),
            ),
          ],
        ),
        if (loading) ...[
          const SizedBox(height: 12),
          const LinearProgressIndicator(minHeight: 3),
        ],
        const SizedBox(height: 14),
        Text(text, style: Theme.of(context).textTheme.bodyLarge),
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xffe5e7eb)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _TwoColumn extends StatelessWidget {
  const _TwoColumn({required this.left, required this.right});

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth < 780) {
        return Column(children: [left, const SizedBox(height: 18), right]);
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: left),
          const SizedBox(width: 18),
          Expanded(child: right),
        ],
      );
    });
  }
}

class _CashBucketChart extends StatelessWidget {
  const _CashBucketChart({required this.buckets});

  final List<_CashForecastBucket> buckets;

  @override
  Widget build(BuildContext context) {
    final maxValue = buckets.fold(
        0.0,
        (value, bucket) =>
            math.max(value, math.max(bucket.scheduled, bucket.likely)));
    if (maxValue <= 0) return const _EmptyChart();
    return Column(
      children: [
        SizedBox(
          height: 300,
          child: BarChart(
            BarChartData(
              minY: 0,
              maxY: maxValue * 1.18,
              borderData: FlBorderData(show: false),
              gridData: const FlGridData(show: true),
              titlesData:
                  _chartTitles(buckets.map((bucket) => bucket.label).toList()),
              barGroups: [
                for (var i = 0; i < buckets.length; i++)
                  BarChartGroupData(
                    x: i,
                    barsSpace: 5,
                    barRods: [
                      BarChartRodData(
                        toY: buckets[i].scheduled,
                        color: Colors.blue,
                        width: 11,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      BarChartRodData(
                        toY: buckets[i].likely,
                        color: Colors.green,
                        width: 11,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        const _ChartLegend(items: [
          _LegendItem('Scheduled', Colors.blue),
          _LegendItem('Likely', Colors.green),
        ]),
      ],
    );
  }
}

class _DailyCashLineChart extends StatelessWidget {
  const _DailyCashLineChart({required this.rows});

  final List<_DailyProjection> rows;

  @override
  Widget build(BuildContext context) {
    final maxValue = rows.fold(
        0.0,
        (value, row) =>
            math.max(value, math.max(row.scheduled, row.likelyCollection)));
    if (maxValue <= 0) return const _EmptyChart();
    return Column(
      children: [
        SizedBox(
          height: 300,
          child: LineChart(
            LineChartData(
              minY: 0,
              maxY: maxValue * 1.2,
              borderData: FlBorderData(show: false),
              gridData: const FlGridData(show: true),
              titlesData: _chartTitles(rows.map((row) => row.label).toList(),
                  bottomEvery: 2),
              lineBarsData: [
                _projectionLine(rows, (row) => row.scheduled, Colors.indigo),
                _projectionLine(
                    rows, (row) => row.likelyCollection, Colors.teal),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        const _ChartLegend(items: [
          _LegendItem('Scheduled', Colors.indigo),
          _LegendItem('Likely', Colors.teal),
        ]),
      ],
    );
  }
}

class _RiskExposureChart extends StatelessWidget {
  const _RiskExposureChart({required this.bands});

  final List<_RiskExposureBand> bands;

  @override
  Widget build(BuildContext context) {
    final maxValue =
        bands.fold(0.0, (value, band) => math.max(value, band.value));
    if (maxValue <= 0) return const _EmptyChart();
    return Column(
      children: [
        SizedBox(
          height: 300,
          child: BarChart(
            BarChartData(
              minY: 0,
              maxY: maxValue * 1.16,
              borderData: FlBorderData(show: false),
              gridData: const FlGridData(show: true),
              titlesData:
                  _chartTitles(bands.map((band) => band.label).toList()),
              barGroups: [
                for (var i = 0; i < bands.length; i++)
                  BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: bands[i].value,
                        color: bands[i].color,
                        width: 28,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        _ChartLegend(
            items: bands
                .map((band) => _LegendItem(
                    '${band.label} ${moneyFormat.format(band.value)}',
                    band.color))
                .toList()),
      ],
    );
  }
}

class _InventoryLiquidityChart extends StatelessWidget {
  const _InventoryLiquidityChart({required this.slices});

  final List<_InventorySlice> slices;

  @override
  Widget build(BuildContext context) {
    final total = slices.fold(0.0, (sum, slice) => sum + slice.value);
    if (total <= 0) return const _EmptyChart();
    return Column(
      children: [
        SizedBox(
          height: 260,
          child: PieChart(
            PieChartData(
              centerSpaceRadius: 46,
              sectionsSpace: 2,
              sections: [
                for (final slice in slices)
                  PieChartSectionData(
                    value: slice.value,
                    color: slice.color,
                    radius: 78,
                    title:
                        '${((slice.value / total) * 100).round().clamp(1, 100)}%',
                    titleStyle: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 12),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        _ChartLegend(
            items: slices
                .map((slice) => _LegendItem(
                    '${slice.label} ${moneyFormat.format(slice.value)}',
                    slice.color))
                .toList()),
      ],
    );
  }
}

class _PriorityLoanList extends StatelessWidget {
  const _PriorityLoanList({required this.loans});

  final List<LoanRecord> loans;

  @override
  Widget build(BuildContext context) {
    if (loans.isEmpty) {
      return const Text('No open collection priorities.');
    }
    return Column(
      children: loans
          .map((loan) => _PriorityLoanTile(loan: loan))
          .expand((tile) => [tile, const Divider(height: 1)])
          .toList()
        ..removeLast(),
    );
  }
}

class _PriorityLoanTile extends StatelessWidget {
  const _PriorityLoanTile({required this.loan});

  final LoanRecord loan;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: Color(loan.risk.colorHex),
        child: Text('${loan.riskScore}',
            style: const TextStyle(color: Colors.white, fontSize: 12)),
      ),
      title: Text(loan.client,
          style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(
        '${loan.item}\nDue ${_dateOrMissing(loan.dueDate)} - ${loan.risk.label} - ${loan.overdueDays} days overdue',
      ),
      isThreeLine: true,
      trailing: Text(moneyFormat.format(loan.remaining),
          style: const TextStyle(fontWeight: FontWeight.w900)),
    );
  }
}

class _InventoryActionList extends StatelessWidget {
  const _InventoryActionList({required this.items});

  final List<InventoryRecord> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Text('No available inventory actions.');
    }
    return Column(
      children: items
          .map((item) => _InventoryActionTile(item: item))
          .expand((tile) => [tile, const Divider(height: 1)])
          .toList()
        ..removeLast(),
    );
  }
}

class _InventoryActionTile extends StatelessWidget {
  const _InventoryActionTile({required this.item});

  final InventoryRecord item;

  @override
  Widget build(BuildContext context) {
    final age = item.age == null ? 'no list date' : '${item.age} days listed';
    final daysHeld =
        item.daysHeld == null ? 'unknown hold' : '${item.daysHeld} days held';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor:
            item.age == null || item.age! >= 21 ? Colors.orange : Colors.teal,
        child: const Icon(Icons.sell_outlined, color: Colors.white, size: 18),
      ),
      title: Text(item.product,
          style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text('${item.category}\n$age - $daysHeld'),
      isThreeLine: true,
      trailing: Text(moneyFormat.format(item.value),
          style: const TextStyle(fontWeight: FontWeight.w900)),
    );
  }
}

class _ControlPointGrid extends StatelessWidget {
  const _ControlPointGrid({required this.snapshot});

  final _ForecastSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final rows = [
      _ControlPoint(
          'Floor collection rate', _percent(snapshot.floorCollectionRate)),
      _ControlPoint(
          'Base collection rate', _percent(snapshot.baseCollectionRate)),
      _ControlPoint(
          'Stretch collection rate', _percent(snapshot.stretchCollectionRate)),
      _ControlPoint('Open loans', '${snapshot.openLoanCount}'),
      _ControlPoint('Average daily likely cash',
          moneyFormat.format(snapshot.averageDailyLikely)),
      _ControlPoint('Inventory liquidation value',
          moneyFormat.format(snapshot.liquidationValue)),
      _ControlPoint(
          '7-day scheduled cash', moneyFormat.format(snapshot.next7Scheduled)),
      _ControlPoint('30-day scheduled cash',
          moneyFormat.format(snapshot.next30Scheduled)),
    ];

    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth < 680
          ? constraints.maxWidth
          : (constraints.maxWidth - 12) / 2;
      return Wrap(
        spacing: 12,
        runSpacing: 8,
        children: rows
            .map((row) => SizedBox(width: width, child: _ControlPointRow(row)))
            .toList(),
      );
    });
  }
}

class _ControlPoint {
  const _ControlPoint(this.label, this.value);

  final String label;
  final String value;
}

class _ControlPointRow extends StatelessWidget {
  const _ControlPointRow(this.row);

  final _ControlPoint row;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: const Color(0xfff8fafc),
      ),
      child: Row(
        children: [
          Expanded(child: Text(row.label)),
          const SizedBox(width: 10),
          Text(row.value, style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status, required this.loading});

  final String status;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: loading
            ? Colors.indigo.withValues(alpha: .1)
            : Colors.green.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: loading
              ? Colors.indigo.withValues(alpha: .22)
              : Colors.green.withValues(alpha: .22),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(loading ? Icons.sync : Icons.check_circle_outline,
              size: 16, color: loading ? Colors.indigo : Colors.green),
          const SizedBox(width: 6),
          Text(status,
              style:
                  const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
        ],
      ),
    );
  }
}

class _ChartLegend extends StatelessWidget {
  const _ChartLegend({required this.items});

  final List<_LegendItem> items;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        for (final item in items)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                    color: item.color, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(width: 6),
              Text(item.label, style: Theme.of(context).textTheme.bodySmall),
            ],
          )
      ],
    );
  }
}

class _LegendItem {
  const _LegendItem(this.label, this.color);

  final String label;
  final Color color;
}

class _EmptyChart extends StatelessWidget {
  const _EmptyChart();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
        height: 180, child: Center(child: Text('No forecast data available.')));
  }
}

_CashForecastBucket _buildBucket(
  String label,
  List<LoanRecord> loans,
  int startDay,
  int endDay,
  double baseRate,
  double floorRate,
  double stretchRate,
  double timeConfidence,
) {
  final bucketLoans = _loansDueBetween(loans, startDay, endDay);
  final scheduled = bucketLoans.fold(0.0, (sum, loan) => sum + loan.remaining);
  final likely = bucketLoans.fold(
      0.0,
      (sum, loan) =>
          sum + (loan.remaining * _loanCollectionRate(loan, baseRate)));
  final floor = math.min(
      scheduled, scheduled * _clampDouble(floorRate * timeConfidence, .04, .8));
  final stretch = math.min(scheduled,
      scheduled * _clampDouble(stretchRate * timeConfidence, .08, .94));
  return _CashForecastBucket(
    label: label,
    scheduled: scheduled,
    floor: floor,
    likely: math.min(scheduled, likely * timeConfidence),
    stretch: math.max(likely, stretch),
  );
}

_DailyProjection _buildDailyProjection(
    List<LoanRecord> loans, int day, double baseRate) {
  final date =
      DateTime(today.year, today.month, today.day).add(Duration(days: day));
  final dayLoans = _loansDueBetween(loans, day, day);
  final scheduled = dayLoans.fold(0.0, (sum, loan) => sum + loan.remaining);
  final likely = dayLoans.fold(
      0.0,
      (sum, loan) =>
          sum + (loan.remaining * _loanCollectionRate(loan, baseRate)));
  return _DailyProjection(
    label: '${date.day}/${date.month}',
    date: date,
    scheduled: scheduled,
    likelyCollection: math.min(scheduled, likely),
  );
}

List<LoanRecord> _loansDueBetween(
    List<LoanRecord> loans, int startDay, int endDay) {
  return loans.where((loan) {
    if (loan.dueDate == null) return false;
    final days = daysBetween(loan.dueDate!, today);
    return days >= startDay && days <= endDay;
  }).toList();
}

double _loanCollectionRate(LoanRecord loan, double baseRate) {
  var rate = baseRate;
  rate -= (loan.riskScore / 100) * .18;
  if (loan.overdueDays > 0) {
    rate -= math.min(.22, loan.overdueDays * .006);
  }
  if (loan.paid > 0 && loan.remaining > 0) {
    rate += .06;
  }
  if (loan.dueDate != null && daysBetween(loan.dueDate!, today) <= 2) {
    rate += .04;
  }
  return _clampDouble(rate, .06, .88);
}

double _loanPriorityScore(LoanRecord loan) {
  final dueDistance =
      loan.dueDate == null ? 30 : daysBetween(loan.dueDate!, today).abs();
  final dueBoost = dueDistance <= 3
      ? 650.0
      : dueDistance <= 7
          ? 320.0
          : 0.0;
  return loan.remaining * (1 + (loan.riskScore / 100)) +
      math.max(0, loan.overdueDays) * 160 +
      dueBoost;
}

double _inventoryActionScore(InventoryRecord item) {
  final age = item.age ?? 45;
  final ageBoost = age >= 45
      ? 1.45
      : age >= 21
          ? 1.2
          : 1.0;
  return item.value * ageBoost + age * 18;
}

double _sumWhere(
  List<LoanRecord> loans,
  bool Function(LoanRecord loan) test,
  double Function(LoanRecord loan) value,
) {
  return loans.where(test).fold(0.0, (sum, loan) => sum + value(loan));
}

double _clampDouble(double value, double min, double max) {
  return value.clamp(min, max).toDouble();
}

LineChartBarData _projectionLine(
  List<_DailyProjection> rows,
  double Function(_DailyProjection row) value,
  Color color,
) {
  return LineChartBarData(
    spots: [
      for (var i = 0; i < rows.length; i++) FlSpot(i.toDouble(), value(rows[i]))
    ],
    isCurved: true,
    color: color,
    barWidth: 3,
    belowBarData: BarAreaData(show: true, color: color.withValues(alpha: .1)),
    dotData: const FlDotData(show: false),
  );
}

FlTitlesData _chartTitles(List<String> labels, {int bottomEvery = 1}) {
  return FlTitlesData(
    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    leftTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 46,
        getTitlesWidget: (value, meta) {
          if (value < 0) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Text(_compactMoney(value),
                style: const TextStyle(fontSize: 10)),
          );
        },
      ),
    ),
    bottomTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 38,
        getTitlesWidget: (value, meta) {
          final index = value.toInt();
          if (index < 0 || index >= labels.length || index % bottomEvery != 0) {
            return const SizedBox.shrink();
          }
          return Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(labels[index], style: const TextStyle(fontSize: 10)),
          );
        },
      ),
    ),
  );
}

String _localForecastText(_ForecastSnapshot snapshot) {
  final topLoan = snapshot.collectionPriorities.isEmpty
      ? null
      : snapshot.collectionPriorities.first;
  final topItem = snapshot.inventoryActions.isEmpty
      ? null
      : snapshot.inventoryActions.first;
  final collectionAction = topLoan == null
      ? 'No open loan needs immediate collection prioritization.'
      : 'Start with ${topLoan.client}: ${moneyFormat.format(topLoan.remaining)} open on ${topLoan.item}, ${topLoan.risk.label.toLowerCase()}.';
  final inventoryAction = topItem == null
      ? 'No inventory move is currently flagged.'
      : 'Move ${topItem.product}: ${moneyFormat.format(topItem.value)} listed value, ${topItem.age == null ? 'no list date' : '${topItem.age} days listed'}.';

  return [
    'Local projection: ${moneyFormat.format(snapshot.next7Likely)} likely cash over 7 days from ${moneyFormat.format(snapshot.next7Scheduled)} scheduled.',
    '30-day likely cash is ${moneyFormat.format(snapshot.next30Likely)} with ${moneyFormat.format(snapshot.cashAtRisk30)} at risk after borrower risk and overdue drag.',
    'Overdue exposure is ${moneyFormat.format(snapshot.overdueExposure)} and high-risk exposure is ${moneyFormat.format(snapshot.highRiskExposure)}.',
    collectionAction,
    inventoryAction,
  ].map((line) => '- $line').join('\n');
}

String _compactMoney(double value) {
  final abs = value.abs();
  if (abs >= 1000000) {
    return '${(value / 1000000).toStringAsFixed(abs >= 10000000 ? 0 : 1)}m';
  }
  if (abs >= 1000) {
    return '${(value / 1000).toStringAsFixed(abs >= 10000 ? 0 : 1)}k';
  }
  return value.round().toString();
}

String _percent(double value) => '${(value * 100).round()}%';

String _dateOrMissing(DateTime? date) {
  final value = dateInputValue(date);
  return value.isEmpty ? 'missing' : value;
}

const _sliceColors = [
  Colors.blue,
  Colors.teal,
  Colors.orange,
  Colors.purple,
  Colors.green,
];
