import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/pawntrack_models.dart';
import '../services/pawntrack_analytics_ai_service.dart';
import '../widgets/stat_card.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({
    super.key,
    required this.model,
    this.aiService,
  });

  final PawnTrackModel model;
  final PawnTrackAnalyticsAiService? aiService;

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  late final PawnTrackAnalyticsAiService _aiService;
  late AnalyticsAiBrief _brief;
  bool _loadingBrief = true;
  int _briefRequest = 0;

  @override
  void initState() {
    super.initState();
    _aiService = widget.aiService ?? PawnTrackAnalyticsAiService();
    _brief = AnalyticsAiBrief.local(widget.model);
    _loadBrief();
  }

  @override
  void didUpdateWidget(covariant AnalyticsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_modelSignature(oldWidget.model) != _modelSignature(widget.model)) {
      setState(() {
        _brief = AnalyticsAiBrief.local(widget.model);
        _loadingBrief = true;
      });
      _loadBrief();
    }
  }

  Future<void> _loadBrief() async {
    final request = ++_briefRequest;
    setState(() => _loadingBrief = true);
    final brief = await _aiService.generateBrief(widget.model);
    if (!mounted || request != _briefRequest) return;
    setState(() {
      _brief = brief;
      _loadingBrief = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _AnalyticsSnapshot.fromModel(widget.model);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _AnalyticsHeader(
          loading: _loadingBrief,
          generatedByAi: _brief.generatedByAi,
          onRefresh: _loadBrief,
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: snapshot.kpis
              .map((kpi) => SizedBox(
                    width: 210,
                    child: StatCard(
                      label: kpi.label,
                      value: kpi.value,
                      tone: kpi.tone,
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 18),
        _AnalyticsPanel(
          title: 'AI Operations Brief',
          trailing: _BriefSourceChip(
            generatedByAi: _brief.generatedByAi,
            fallbackReason: _brief.fallbackReason,
          ),
          child: _AiBriefView(brief: _brief, loading: _loadingBrief),
        ),
        const SizedBox(height: 18),
        _ResponsiveGrid(
          children: [
            _AnalyticsPanel(
              title: 'Collections Forecast',
              child: _MoneyBarChart(points: snapshot.dueWindows),
            ),
            _AnalyticsPanel(
              title: 'Cash Conversion',
              child: _MoneyBarChart(points: snapshot.cashConversion),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _ResponsiveGrid(
          children: [
            _AnalyticsPanel(
              title: 'Risk Exposure',
              child: Column(
                children: [
                  _SegmentBarChart(segments: snapshot.riskSegments),
                  const SizedBox(height: 12),
                  _SegmentList(segments: snapshot.riskSegments),
                ],
              ),
            ),
            _AnalyticsPanel(
              title: 'Loan Book Segments',
              child: Column(
                children: [
                  _SegmentBarChart(segments: snapshot.loanBookSegments),
                  const SizedBox(height: 12),
                  _SegmentList(segments: snapshot.loanBookSegments),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _ResponsiveGrid(
          children: [
            _AnalyticsPanel(
              title: 'Inventory Categories',
              child: _CategoryPieChart(segments: snapshot.categorySegments),
            ),
            _AnalyticsPanel(
              title: 'Inventory Aging',
              child: Column(
                children: [
                  _SegmentBarChart(segments: snapshot.inventoryAging),
                  const SizedBox(height: 12),
                  _SegmentList(segments: snapshot.inventoryAging),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _AnalyticsPanel(
          title: 'Monthly Operating Trend',
          child: _MonthlyTrendChart(rows: widget.model.monthlyGrowth),
        ),
        const SizedBox(height: 18),
        _ResponsiveGrid(
          children: [
            _AnalyticsPanel(
              title: 'Collection Priorities',
              child: _LoanPriorityList(loans: snapshot.collectionPriorities),
            ),
            _AnalyticsPanel(
              title: 'Inventory Actions',
              child: _InventoryPriorityList(items: snapshot.inventoryActions),
            ),
            _AnalyticsPanel(
              title: 'Location Exposure',
              child: _SegmentList(segments: snapshot.locationSegments),
            ),
          ],
        ),
      ],
    );
  }
}

class _AnalyticsHeader extends StatelessWidget {
  const _AnalyticsHeader({
    required this.loading,
    required this.generatedByAi,
    required this.onRefresh,
  });

  final bool loading;
  final bool generatedByAi;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final chipColor = generatedByAi ? Colors.indigo : Colors.blueGrey;
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      alignment: WrapAlignment.spaceBetween,
      children: [
        Text(
          'Analytics',
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.w900),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Chip(
              avatar: Icon(
                generatedByAi
                    ? Icons.auto_awesome_outlined
                    : Icons.analytics_outlined,
                size: 18,
                color: chipColor,
              ),
              label: Text(loading
                  ? 'Refreshing'
                  : generatedByAi
                      ? 'Firebase AI'
                      : 'Local fallback'),
              side: BorderSide(color: chipColor.withValues(alpha: .3)),
              backgroundColor: chipColor.withValues(alpha: .08),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: 'Refresh AI brief',
              child: IconButton.filledTonal(
                onPressed: loading ? null : onRefresh,
                icon: const Icon(Icons.refresh),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _AiBriefView extends StatelessWidget {
  const _AiBriefView({required this.brief, required this.loading});

  final AnalyticsAiBrief brief;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (loading) ...[
          const LinearProgressIndicator(minHeight: 3),
          const SizedBox(height: 12),
        ],
        Text(
          brief.summary,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 16),
        _ResponsiveGrid(
          minChildWidth: 260,
          children: [
            _ActionGroup(
              title: 'Collections',
              icon: Icons.call_outlined,
              color: Colors.green,
              actions: brief.collectionActions,
            ),
            _ActionGroup(
              title: 'Cash',
              icon: Icons.account_balance_wallet_outlined,
              color: Colors.blue,
              actions: brief.cashActions,
            ),
            _ActionGroup(
              title: 'Risk',
              icon: Icons.warning_amber_outlined,
              color: Colors.red,
              actions: brief.riskActions,
            ),
            _ActionGroup(
              title: 'Inventory',
              icon: Icons.inventory_2_outlined,
              color: Colors.orange,
              actions: brief.inventoryActions,
            ),
          ],
        ),
      ],
    );
  }
}

class _ActionGroup extends StatelessWidget {
  const _ActionGroup({
    required this.title,
    required this.icon,
    required this.color,
    required this.actions,
  });

  final String title;
  final IconData icon;
  final Color color;
  final List<String> actions;

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...actions.map(
          (action) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(top: 8, right: 8),
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(child: Text(action)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _BriefSourceChip extends StatelessWidget {
  const _BriefSourceChip({
    required this.generatedByAi,
    this.fallbackReason,
  });

  final bool generatedByAi;
  final String? fallbackReason;

  @override
  Widget build(BuildContext context) {
    if (generatedByAi) {
      return const Chip(
        avatar: Icon(Icons.auto_awesome_outlined, size: 18),
        label: Text('AI'),
      );
    }
    return Tooltip(
      message: fallbackReason == null || fallbackReason!.isEmpty
          ? 'Deterministic local analytics'
          : fallbackReason!,
      child: const Chip(
        avatar: Icon(Icons.offline_bolt_outlined, size: 18),
        label: Text('Local'),
      ),
    );
  }
}

class _AnalyticsPanel extends StatelessWidget {
  const _AnalyticsPanel({
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _ResponsiveGrid extends StatelessWidget {
  const _ResponsiveGrid({
    required this.children,
    this.minChildWidth = 360,
  });

  final List<Widget> children;
  final int minChildWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 16.0;
        final columns = max(1, constraints.maxWidth ~/ minChildWidth);
        final width =
            (constraints.maxWidth - (columns - 1) * spacing) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: children
              .map((child) => SizedBox(width: width, child: child))
              .toList(),
        );
      },
    );
  }
}

class _MoneyBarChart extends StatelessWidget {
  const _MoneyBarChart({required this.points});

  final List<_BarPoint> points;

  @override
  Widget build(BuildContext context) {
    if (!points.any((point) => point.value > 0)) return const _EmptyChart();
    return SizedBox(
      height: 290,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(show: true),
          titlesData: _chartTitles(points.map((point) => point.label).toList()),
          barGroups: [
            for (var i = 0; i < points.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: max(0, points[i].value).toDouble(),
                    color: points[i].color,
                    width: 24,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _SegmentBarChart extends StatelessWidget {
  const _SegmentBarChart({required this.segments});

  final List<_AnalyticsSegment> segments;

  @override
  Widget build(BuildContext context) {
    if (!segments.any((segment) => segment.value > 0)) {
      return const _EmptyChart();
    }
    return SizedBox(
      height: 240,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(show: true),
          titlesData:
              _chartTitles(segments.map((segment) => segment.name).toList()),
          barGroups: [
            for (var i = 0; i < segments.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: max(0, segments[i].value).toDouble(),
                    color: segments[i].color,
                    width: 22,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _CategoryPieChart extends StatelessWidget {
  const _CategoryPieChart({required this.segments});

  final List<_AnalyticsSegment> segments;

  @override
  Widget build(BuildContext context) {
    final total = segments.fold(0.0, (sum, segment) => sum + segment.value);
    if (total <= 0) return const _EmptyChart();
    return LayoutBuilder(
      builder: (context, constraints) {
        final chart = SizedBox(
          height: 260,
          width: min(300, constraints.maxWidth).toDouble(),
          child: PieChart(
            PieChartData(
              centerSpaceRadius: 42,
              sectionsSpace: 2,
              sections: [
                for (final segment in segments)
                  PieChartSectionData(
                    value: max(.01, segment.value).toDouble(),
                    color: segment.color,
                    radius: 76,
                    title: '${(segment.value / total * 100).round()}%',
                    titleStyle: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
        );
        final legend = _SegmentList(segments: segments, compact: true);
        if (constraints.maxWidth < 560) {
          return Column(children: [chart, const SizedBox(height: 12), legend]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            chart,
            const SizedBox(width: 16),
            Expanded(child: legend),
          ],
        );
      },
    );
  }
}

class _MonthlyTrendChart extends StatelessWidget {
  const _MonthlyTrendChart({required this.rows});

  final List<MonthlyMetric> rows;

  @override
  Widget build(BuildContext context) {
    final data =
        rows.length <= 10 ? rows : rows.skip(rows.length - 10).toList();
    if (data.isEmpty) return const _EmptyChart();
    return Column(
      children: [
        SizedBox(
          height: 320,
          child: LineChart(
            LineChartData(
              minY: 0,
              borderData: FlBorderData(show: false),
              gridData: const FlGridData(show: true),
              titlesData: _chartTitles(data.map((row) => row.month).toList()),
              lineBarsData: [
                _lineFor(data, (row) => row.loans, Colors.blue),
                _lineFor(data, (row) => row.recovered, Colors.green),
                _lineFor(data, (row) => row.profit, Colors.indigo),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        const _ChartLegend(
          items: [
            _LegendItem('Loans', Colors.blue),
            _LegendItem('Recovered', Colors.green),
            _LegendItem('Profit', Colors.indigo),
          ],
        ),
      ],
    );
  }
}

class _ChartLegend extends StatelessWidget {
  const _ChartLegend({required this.items});

  final List<_LegendItem> items;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 14,
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
                  color: item.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(item.label),
            ],
          ),
      ],
    );
  }
}

class _SegmentList extends StatelessWidget {
  const _SegmentList({required this.segments, this.compact = false});

  final List<_AnalyticsSegment> segments;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (segments.isEmpty) return const _EmptyChart(height: 120);
    return Column(
      children: segments
          .map(
            (segment) => ListTile(
              dense: compact,
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: segment.color,
                  shape: BoxShape.circle,
                ),
              ),
              title: Text(
                segment.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(segment.detail ?? '${segment.count} records'),
              trailing: Text(
                moneyFormat.format(segment.value),
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _LoanPriorityList extends StatelessWidget {
  const _LoanPriorityList({required this.loans});

  final List<LoanRecord> loans;

  @override
  Widget build(BuildContext context) {
    if (loans.isEmpty) return const _EmptyChart(height: 120);
    return Column(
      children: loans
          .map(
            (loan) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: Color(loan.risk.colorHex),
                child: Text(
                  '${loan.riskScore}',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
              title: Text(
                loan.client,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(
                '${loan.item}\nDue ${dateInputValue(loan.dueDate).isEmpty ? 'missing' : dateInputValue(loan.dueDate)} - ${loan.overdueDays} days overdue',
              ),
              isThreeLine: true,
              trailing: Text(
                moneyFormat.format(loan.remaining),
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _InventoryPriorityList extends StatelessWidget {
  const _InventoryPriorityList({required this.items});

  final List<InventoryRecord> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const _EmptyChart(height: 120);
    return Column(
      children: items
          .map(
            (item) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: Colors.orange.withValues(alpha: .15),
                child: const Icon(Icons.sell_outlined, color: Colors.orange),
              ),
              title: Text(
                item.product,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(
                '${item.category} - ${item.age == null ? 'No list date' : '${item.age} days listed'}',
              ),
              trailing: Text(
                moneyFormat.format(item.value),
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _EmptyChart extends StatelessWidget {
  const _EmptyChart({this.height = 180});

  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: const Center(child: Text('No analytics data available.')),
    );
  }
}

class _AnalyticsSnapshot {
  const _AnalyticsSnapshot({
    required this.kpis,
    required this.dueWindows,
    required this.cashConversion,
    required this.riskSegments,
    required this.loanBookSegments,
    required this.categorySegments,
    required this.inventoryAging,
    required this.locationSegments,
    required this.collectionPriorities,
    required this.inventoryActions,
  });

  final List<_Kpi> kpis;
  final List<_BarPoint> dueWindows;
  final List<_BarPoint> cashConversion;
  final List<_AnalyticsSegment> riskSegments;
  final List<_AnalyticsSegment> loanBookSegments;
  final List<_AnalyticsSegment> categorySegments;
  final List<_AnalyticsSegment> inventoryAging;
  final List<_AnalyticsSegment> locationSegments;
  final List<LoanRecord> collectionPriorities;
  final List<InventoryRecord> inventoryActions;

  factory _AnalyticsSnapshot.fromModel(PawnTrackModel model) {
    final openLoans = model.loans.where((loan) => loan.remaining > 0).toList();
    final highRisk = openLoans.where((loan) => loan.riskScore >= 70).toList();
    final mediumRisk = openLoans
        .where((loan) => loan.riskScore >= 40 && loan.riskScore < 70)
        .toList();
    final lowRisk = openLoans.where((loan) => loan.riskScore < 40).toList();
    final activeOutstanding =
        model.active.fold(0.0, (sum, loan) => sum + loan.remaining);
    final osOutstanding =
        model.os.fold(0.0, (sum, loan) => sum + loan.remaining);
    final agedInventory = model.inventoryAging
        .where((row) => row.bucket == '31+ days')
        .fold(0.0, (sum, row) => sum + row.value);
    final missingPhones =
        openLoans.where((loan) => loan.phone.trim().isEmpty).length;
    final missingSerials =
        model.active.where((loan) => loan.itemSerial.trim().isEmpty).length;
    final avgOpenLoan =
        _safeDivide(model.remaining, openLoans.length.toDouble());
    final overdueShare = _safeDivide(model.overdueAmount, model.remaining);
    final interestYield =
        _safeDivide(model.expectedInterest, model.principalOutstanding);
    final salesMargin = _safeDivide(model.salesProfit, model.salesEarned);
    final collectionPriorities = [...openLoans]..sort((a, b) {
        final risk = b.riskScore.compareTo(a.riskScore);
        if (risk != 0) return risk;
        return b.remaining.compareTo(a.remaining);
      });
    final inventoryActions = [...model.discountItems]..sort((a, b) {
        final age = (b.age ?? 999).compareTo(a.age ?? 999);
        if (age != 0) return age;
        return b.value.compareTo(a.value);
      });

    return _AnalyticsSnapshot(
      kpis: [
        _Kpi('Principal', moneyFormat.format(model.principalOutstanding),
            Colors.blue),
        _Kpi('Expected repayment', moneyFormat.format(model.expectedRepayment),
            Colors.green),
        _Kpi(
            'Open balance', moneyFormat.format(model.remaining), Colors.indigo),
        _Kpi('Collected', moneyFormat.format(model.collected), Colors.teal),
        _Kpi('Collection rate', _percent(model.collectionRate), Colors.green),
        _Kpi('Overdue exposure', moneyFormat.format(model.overdueAmount),
            Colors.red),
        _Kpi('Overdue share', _percent(overdueShare), Colors.red),
        _Kpi('Due today', moneyFormat.format(model.dueToday), Colors.red),
        _Kpi('Due 7 days', moneyFormat.format(model.due7), Colors.orange),
        _Kpi('Due 30 days', moneyFormat.format(model.due30), Colors.blue),
        _Kpi('High-risk clients', '${highRisk.length}', Colors.red),
        _Kpi('Average open loan', moneyFormat.format(avgOpenLoan),
            Colors.blueGrey),
        _Kpi('Interest yield', _percent(interestYield), Colors.indigo),
        _Kpi('Inventory value', moneyFormat.format(model.inventoryValue),
            Colors.orange),
        _Kpi('Aged inventory', moneyFormat.format(agedInventory),
            Colors.deepOrange),
        _Kpi('Discount items', '${model.discountItems.length}', Colors.orange),
        _Kpi('Sales profit', moneyFormat.format(model.salesProfit),
            Colors.green),
        _Kpi('Sales margin', _percent(salesMargin), Colors.teal),
        _Kpi('Missing phones', '$missingPhones', Colors.blueGrey),
        _Kpi('Missing serials', '$missingSerials', Colors.blueGrey),
      ],
      dueWindows: [
        _BarPoint('Today', model.dueToday, Colors.red),
        _BarPoint('7 days', model.due7, Colors.orange),
        _BarPoint('Next week', model.dueNextWeek, Colors.amber),
        _BarPoint('30 days', model.due30, Colors.blue),
        _BarPoint('90 days', model.due90, Colors.green),
      ],
      cashConversion: [
        _BarPoint('Principal', model.principalOutstanding, Colors.blue),
        _BarPoint('Expected', model.expectedRepayment, Colors.green),
        _BarPoint('Collected', model.collected, Colors.teal),
        _BarPoint('Open', model.remaining, Colors.indigo),
        _BarPoint('Overdue', model.overdueAmount, Colors.red),
      ],
      riskSegments: [
        _loanSegment('High risk', highRisk, Colors.red),
        _loanSegment('Medium risk', mediumRisk, Colors.orange),
        _loanSegment('Low risk', lowRisk, Colors.green),
      ],
      loanBookSegments: [
        _AnalyticsSegment(
          name: 'Active Pawns',
          count: model.active.length,
          value: activeOutstanding,
          color: Colors.blue,
          detail: '${model.active.length} pawn records',
        ),
        _AnalyticsSegment(
          name: 'OS Debts',
          count: model.os.length,
          value: osOutstanding,
          color: Colors.purple,
          detail: '${model.os.length} debt records',
        ),
      ],
      categorySegments: _categorySegments(model.byCategory),
      inventoryAging: [
        for (final row in model.inventoryAging)
          _AnalyticsSegment(
            name: row.bucket,
            count: row.count,
            value: row.value,
            color: _agingColor(row.bucket),
            detail: '${row.count} items',
          ),
      ],
      locationSegments: _loanSegmentsByLocation(openLoans),
      collectionPriorities: collectionPriorities.take(8).toList(),
      inventoryActions: inventoryActions.take(8).toList(),
    );
  }
}

class _Kpi {
  const _Kpi(this.label, this.value, this.tone);

  final String label;
  final String value;
  final Color tone;
}

class _BarPoint {
  const _BarPoint(this.label, this.value, this.color);

  final String label;
  final double value;
  final Color color;
}

class _AnalyticsSegment {
  const _AnalyticsSegment({
    required this.name,
    required this.count,
    required this.value,
    required this.color,
    this.detail,
  });

  final String name;
  final int count;
  final double value;
  final Color color;
  final String? detail;
}

class _LegendItem {
  const _LegendItem(this.label, this.color);

  final String label;
  final Color color;
}

LineChartBarData _lineFor(
  List<MonthlyMetric> rows,
  double Function(MonthlyMetric row) valueOf,
  Color color,
) {
  return LineChartBarData(
    spots: [
      for (var i = 0; i < rows.length; i++)
        FlSpot(i.toDouble(), max(0, valueOf(rows[i])).toDouble()),
    ],
    isCurved: true,
    color: color,
    barWidth: 3,
    belowBarData: BarAreaData(show: true, color: color.withValues(alpha: .08)),
    dotData: const FlDotData(show: false),
  );
}

FlTitlesData _chartTitles(List<String> labels) {
  return FlTitlesData(
    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    leftTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 54,
        getTitlesWidget: (value, meta) => Text(
          _axisMoney(value),
          style: const TextStyle(fontSize: 10),
        ),
      ),
    ),
    bottomTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 50,
        getTitlesWidget: (value, meta) {
          final index = value.toInt();
          if (index < 0 || index >= labels.length) {
            return const SizedBox.shrink();
          }
          return Padding(
            padding: const EdgeInsets.only(top: 8),
            child: SizedBox(
              width: 64,
              child: Text(
                labels[index],
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 10),
              ),
            ),
          );
        },
      ),
    ),
  );
}

_AnalyticsSegment _loanSegment(
  String name,
  List<LoanRecord> loans,
  Color color,
) {
  final value = loans.fold(0.0, (sum, loan) => sum + loan.remaining);
  final overdue = loans.where((loan) => loan.overdueDays > 0).length;
  return _AnalyticsSegment(
    name: name,
    count: loans.length,
    value: value,
    color: color,
    detail: '$overdue overdue / ${loans.length} open',
  );
}

List<_AnalyticsSegment> _categorySegments(List<CategoryMetric> categories) {
  const colors = [
    Colors.blue,
    Colors.orange,
    Colors.green,
    Colors.indigo,
    Colors.red,
    Colors.teal,
  ];
  final top = categories.take(5).toList();
  final segments = <_AnalyticsSegment>[
    for (var i = 0; i < top.length; i++)
      _AnalyticsSegment(
        name: top[i].name,
        count: top[i].count,
        value: top[i].value,
        color: colors[i % colors.length],
        detail: '${top[i].count} items',
      ),
  ];
  final other = categories.skip(5).fold(
        _CategoryAccumulator(),
        (sum, row) => sum
          ..count += row.count
          ..value += row.value,
      );
  if (other.value > 0) {
    segments.add(
      _AnalyticsSegment(
        name: 'Other',
        count: other.count,
        value: other.value,
        color: Colors.blueGrey,
        detail: '${other.count} items',
      ),
    );
  }
  return segments;
}

List<_AnalyticsSegment> _loanSegmentsByLocation(List<LoanRecord> loans) {
  const colors = [
    Colors.cyan,
    Colors.deepPurple,
    Colors.green,
    Colors.orange,
    Colors.red,
    Colors.blueGrey,
  ];
  final groups = <String, _CategoryAccumulator>{};
  for (final loan in loans) {
    final name =
        loan.location.trim().isEmpty ? 'Unknown' : loan.location.trim();
    final group = groups.putIfAbsent(name, () => _CategoryAccumulator());
    group.count += 1;
    group.value += loan.remaining;
  }
  final entries = groups.entries.toList()
    ..sort((a, b) => b.value.value.compareTo(a.value.value));
  return [
    for (var i = 0; i < min(6, entries.length); i++)
      _AnalyticsSegment(
        name: entries[i].key,
        count: entries[i].value.count,
        value: entries[i].value.value,
        color: colors[i % colors.length],
        detail: '${entries[i].value.count} open loans',
      ),
  ];
}

Color _agingColor(String bucket) {
  return switch (bucket) {
    '0-14 days' => Colors.green,
    '15-30 days' => Colors.orange,
    _ => Colors.red,
  };
}

double _safeDivide(double numerator, double denominator) {
  if (denominator == 0 || denominator.isNaN) return 0;
  final result = numerator / denominator;
  return result.isFinite ? result : 0;
}

String _percent(double value) {
  if (!value.isFinite) return '0%';
  return '${(value * 100).round()}%';
}

String _axisMoney(double value) {
  final absValue = value.abs();
  if (absValue >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}m';
  if (absValue >= 1000) return '${(value / 1000).toStringAsFixed(0)}k';
  return value.round().toString();
}

String _modelSignature(PawnTrackModel model) {
  return [
    model.source.syncedAt?.toIso8601String() ?? '',
    model.loans.length,
    model.inventory.length,
    model.remaining.round(),
    model.inventoryValue.round(),
  ].join('|');
}

class _CategoryAccumulator {
  int count = 0;
  double value = 0;
}
