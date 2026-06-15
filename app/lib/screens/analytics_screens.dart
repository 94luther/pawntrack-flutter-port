import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/pawntrack_models.dart';
import '../widgets/stat_card.dart';

class GrowthScreen extends StatelessWidget {
  const GrowthScreen({super.key, required this.model});

  final PawnTrackModel model;

  @override
  Widget build(BuildContext context) {
    final rows = model.monthlyGrowth;
    return _DashboardScaffold(
      title: 'Growth',
      cards: [
        StatCard(label: 'Loans by week', value: moneyFormat.format(model.weekly.fold(0.0, (sum, row) => sum + row.loans)), tone: Colors.blue),
        StatCard(label: 'Loans by month', value: moneyFormat.format(rows.fold(0.0, (sum, row) => sum + row.loans)), tone: Colors.indigo),
        StatCard(label: 'Inventory growth', value: moneyFormat.format(model.inventoryValue), tone: Colors.orange),
        StatCard(label: 'Profit growth', value: moneyFormat.format(model.expectedInterest), tone: Colors.green),
      ],
      children: [
        _Panel(title: 'Monthly cash deployed and recovered', child: _BarMetricChart(rows: rows, firstLabel: 'Loans', secondLabel: 'Recovered')),
        _Panel(title: 'Cashflow line chart', child: _LineMetricChart(rows: rows, firstLabel: 'Loans', secondLabel: 'Recovered')),
        _Panel(title: 'Profit line chart', child: _SingleLineMetricChart(rows: rows, label: 'Profit')),
      ],
    );
  }
}

class CollectionsScreen extends StatelessWidget {
  const CollectionsScreen({super.key, required this.model});

  final PawnTrackModel model;

  @override
  Widget build(BuildContext context) {
    final priorities = [...model.loans.where((loan) => loan.remaining > 0)]..sort((a, b) => b.riskScore.compareTo(a.riskScore));
    return _DashboardScaffold(
      title: 'Collections',
      cards: [
        StatCard(label: 'Collected', value: moneyFormat.format(model.collected), tone: Colors.green),
        StatCard(label: 'Remaining', value: moneyFormat.format(model.remaining), tone: Colors.blueGrey),
        StatCard(label: 'Overdue exposure', value: moneyFormat.format(model.overdueAmount), tone: Colors.red),
        StatCard(label: 'Collection rate', value: '${(model.collectionRate * 100).round()}%', tone: Colors.indigo),
      ],
      children: [
        _Panel(title: 'Collections trend chart', child: _LineMetricChart(rows: model.monthlyGrowth, firstLabel: 'Repayment', secondLabel: 'Recovered')),
        _Panel(
          title: 'Actionable Loans',
          child: Column(children: priorities.take(12).map((loan) => _LoanTile(loan: loan)).toList()),
        ),
        _Panel(
          title: 'All Open Loans',
          child: Column(children: model.loans.where((loan) => loan.remaining > 0).map((loan) => _LoanTile(loan: loan)).toList()),
        ),
      ],
    );
  }
}

class CashScreen extends StatelessWidget {
  const CashScreen({super.key, required this.model});

  final PawnTrackModel model;

  @override
  Widget build(BuildContext context) {
    final forecast = [
      _ForecastPoint('Today', model.dueToday),
      _ForecastPoint('7 days', model.due7),
      _ForecastPoint('Next week', model.dueNextWeek),
      _ForecastPoint('30 days', model.due30),
      _ForecastPoint('90 days', model.due90),
    ];
    return _DashboardScaffold(
      title: 'Cash',
      cards: [
        StatCard(label: 'Due today', value: moneyFormat.format(model.dueToday), tone: Colors.red),
        StatCard(label: 'Due 7 days', value: moneyFormat.format(model.due7), tone: Colors.orange),
        StatCard(label: 'Due 30 days', value: moneyFormat.format(model.due30), tone: Colors.blue),
        StatCard(label: 'Due 90 days', value: moneyFormat.format(model.due90), tone: Colors.green),
      ],
      children: [
        _Panel(title: 'Cash forecast dashboard', child: _ForecastBarChart(points: forecast)),
        _Panel(
          title: 'Upcoming collections',
          child: Column(
            children: ([...model.loans.where((loan) => loan.dueDate != null && loan.remaining > 0)]
                  ..sort((a, b) => a.dueDate!.compareTo(b.dueDate!)))
                .take(16)
                .map((loan) => _LoanTile(loan: loan))
                .toList(),
          ),
        ),
      ],
    );
  }
}

class ProfitScreen extends StatelessWidget {
  const ProfitScreen({super.key, required this.model});

  final PawnTrackModel model;

  @override
  Widget build(BuildContext context) {
    return _DashboardScaffold(
      title: 'Profit',
      cards: [
        StatCard(label: 'Expected interest', value: moneyFormat.format(model.expectedInterest), tone: Colors.green),
        StatCard(label: 'Inventory value', value: moneyFormat.format(model.inventoryValue), tone: Colors.orange),
        StatCard(label: 'Sales profit', value: moneyFormat.format(model.salesProfit), tone: Colors.teal),
        StatCard(label: 'Expected net profit', value: moneyFormat.format(model.expectedNetProfit), tone: Colors.indigo),
      ],
      children: [
        _Panel(title: 'Profit forecast area chart', child: _ProfitAreaChart(rows: model.monthlyGrowth)),
        _Panel(
          title: 'Profit contributors',
          child: Column(
            children: [
              _MetricRow(label: 'Interest expected', value: model.expectedInterest),
              _MetricRow(label: 'Sales earned', value: model.salesEarned),
              _MetricRow(label: 'Sales profit', value: model.salesProfit.toDouble()),
              _MetricRow(label: 'Inventory value', value: model.inventoryValue),
            ],
          ),
        ),
      ],
    );
  }
}

class LiveScreen extends StatelessWidget {
  const LiveScreen({super.key, required this.model, required this.status, required this.writeStatus, required this.onRefresh});

  final PawnTrackModel model;
  final String status;
  final String writeStatus;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return _DashboardScaffold(
      title: 'Live',
      cards: [
        StatCard(label: 'Rows synced', value: '${model.loans.length + model.inventory.length}', tone: Colors.blue),
        StatCard(label: 'Loans', value: '${model.loans.length}', tone: Colors.indigo),
        StatCard(label: 'Inventory', value: '${model.inventory.length}', tone: Colors.orange),
        StatCard(label: 'Sold items', value: '${model.soldInventory.length}', tone: Colors.green),
      ],
      children: [
        _Panel(
          title: 'Live Google Sheets Control',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _StatusLine(label: 'Read status', value: status),
              _StatusLine(label: 'Write status', value: writeStatus),
              _StatusLine(label: 'Source', value: model.source.source),
              _StatusLine(label: 'Last sync', value: model.source.syncedAt?.toLocal().toString() ?? 'Unknown'),
              const SizedBox(height: 12),
              FilledButton.icon(onPressed: onRefresh, icon: const Icon(Icons.refresh), label: const Text('Refresh Sheet Data')),
            ],
          ),
        ),
      ],
    );
  }
}

class AiScreen extends StatefulWidget {
  const AiScreen({super.key, required this.model});

  final PawnTrackModel model;

  @override
  State<AiScreen> createState() => _AiScreenState();
}

class _AiScreenState extends State<AiScreen> {
  String analysis = 'Choose an AI action to generate business guidance from the synced NEW ONE sheet data.';

  @override
  Widget build(BuildContext context) {
    final actions = <String, String Function()>{
      'Analyze Business': () => 'Business health: ${moneyFormat.format(widget.model.expectedRepayment)} expected repayment against ${moneyFormat.format(widget.model.principalOutstanding)} principal. Collection rate is ${(widget.model.collectionRate * 100).round()}% and overdue exposure is ${moneyFormat.format(widget.model.overdueAmount)}.',
      'Forecast Next Month': () => 'Next 30 days: scheduled collections are ${moneyFormat.format(widget.model.due30)}. A conservative likely range is ${moneyFormat.format(widget.model.due30 * .35)} to ${moneyFormat.format(widget.model.due30 * .68)}.',
      'Predict Cash Position': () => 'Cash position: next 7 days scheduled collections are ${moneyFormat.format(widget.model.due7)}. Current available inventory is ${moneyFormat.format(widget.model.inventoryValue)} and logged sales earned are ${moneyFormat.format(widget.model.salesEarned)}.',
      'Identify Risky Clients': () => widget.model.loans.where((loan) => loan.riskScore >= 70).map((loan) => '${loan.client}: ${moneyFormat.format(loan.remaining)}, ${loan.overdueDays} days overdue').join('; ').ifEmpty('No high-risk clients in the current scoring model.'),
      'Recommend Collection Priorities': () => ([...widget.model.loans.where((loan) => loan.remaining > 0)]..sort((a, b) => b.riskScore.compareTo(a.riskScore))).take(6).map((loan) => '${loan.client}: ${moneyFormat.format(loan.remaining)} due ${dateInputValue(loan.dueDate).ifEmpty('missing')}').join('; '),
      'Recommend Inventory Discounts': () => widget.model.discountItems.take(6).map((item) => '${item.product}: ${moneyFormat.format(item.value)}, ${item.age == null ? 'no list date' : '${item.age} days listed'}').join('; ').ifEmpty('No discount candidates found.'),
    };

    return _DashboardScaffold(
      title: 'AI',
      cards: [
        StatCard(label: 'Risky clients', value: '${widget.model.loans.where((loan) => loan.riskScore >= 70).length}', tone: Colors.red),
        StatCard(label: 'Discount candidates', value: '${widget.model.discountItems.length}', tone: Colors.orange),
        StatCard(label: 'Due 30 days', value: moneyFormat.format(widget.model.due30), tone: Colors.blue),
        StatCard(label: 'Expected net profit', value: moneyFormat.format(widget.model.expectedNetProfit), tone: Colors.green),
      ],
      children: [
        _Panel(
          title: 'AI Analysis',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: actions.entries.map((entry) => FilledButton.tonal(onPressed: () => setState(() => analysis = entry.value()), child: Text(entry.key))).toList(),
              ),
              const SizedBox(height: 14),
              Text(analysis, style: Theme.of(context).textTheme.bodyLarge),
            ],
          ),
        ),
      ],
    );
  }
}

class _DashboardScaffold extends StatelessWidget {
  const _DashboardScaffold({required this.title, required this.cards, required this.children});

  final String title;
  final List<Widget> cards;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 14),
        Wrap(spacing: 12, runSpacing: 12, children: cards.map((card) => SizedBox(width: 220, child: card)).toList()),
        const SizedBox(height: 18),
        ...children.expand((child) => [child, const SizedBox(height: 18)]),
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
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xffe5e7eb))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        child,
      ]),
    );
  }
}

class _BarMetricChart extends StatelessWidget {
  const _BarMetricChart({required this.rows, required this.firstLabel, required this.secondLabel});

  final List<MonthlyMetric> rows;
  final String firstLabel;
  final String secondLabel;

  @override
  Widget build(BuildContext context) {
    final data = rows.take(8).toList();
    if (data.isEmpty) return const _EmptyChart();
    return SizedBox(
      height: 300,
      child: BarChart(
        BarChartData(
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(show: true),
          titlesData: _bottomTitles(data.map((row) => row.month).toList()),
          barGroups: [
            for (var i = 0; i < data.length; i++)
              BarChartGroupData(x: i, barRods: [
                BarChartRodData(toY: _metricValue(data[i], firstLabel), color: Colors.blue, width: 10, borderRadius: BorderRadius.circular(3)),
                BarChartRodData(toY: _metricValue(data[i], secondLabel), color: Colors.green, width: 10, borderRadius: BorderRadius.circular(3)),
              ])
          ],
        ),
      ),
    );
  }
}

class _LineMetricChart extends StatelessWidget {
  const _LineMetricChart({required this.rows, required this.firstLabel, required this.secondLabel});

  final List<MonthlyMetric> rows;
  final String firstLabel;
  final String secondLabel;

  @override
  Widget build(BuildContext context) {
    final data = rows.take(10).toList();
    if (data.isEmpty) return const _EmptyChart();
    return SizedBox(
      height: 300,
      child: LineChart(
        LineChartData(
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(show: true),
          titlesData: _bottomTitles(data.map((row) => row.month).toList()),
          lineBarsData: [
            _line(data, firstLabel, Colors.blue),
            _line(data, secondLabel, Colors.green),
          ],
        ),
      ),
    );
  }
}

class _SingleLineMetricChart extends StatelessWidget {
  const _SingleLineMetricChart({required this.rows, required this.label});

  final List<MonthlyMetric> rows;
  final String label;

  @override
  Widget build(BuildContext context) {
    final data = rows.take(10).toList();
    if (data.isEmpty) return const _EmptyChart();
    return SizedBox(
      height: 300,
      child: LineChart(
        LineChartData(
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(show: true),
          titlesData: _bottomTitles(data.map((row) => row.month).toList()),
          lineBarsData: [_line(data, label, Colors.purple)],
        ),
      ),
    );
  }
}

class _ProfitAreaChart extends StatelessWidget {
  const _ProfitAreaChart({required this.rows});

  final List<MonthlyMetric> rows;

  @override
  Widget build(BuildContext context) {
    final data = rows.take(10).toList();
    if (data.isEmpty) return const _EmptyChart();
    return SizedBox(
      height: 300,
      child: LineChart(
        LineChartData(
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(show: true),
          titlesData: _bottomTitles(data.map((row) => row.month).toList()),
          lineBarsData: [
            LineChartBarData(
              spots: [for (var i = 0; i < data.length; i++) FlSpot(i.toDouble(), max(0, data[i].profit))],
              isCurved: true,
              color: Colors.indigo,
              barWidth: 3,
              belowBarData: BarAreaData(show: true, color: Colors.indigo.withValues(alpha: .18)),
              dotData: const FlDotData(show: false),
            ),
          ],
        ),
      ),
    );
  }
}

class _ForecastPoint {
  const _ForecastPoint(this.label, this.value);

  final String label;
  final double value;
}

class _ForecastBarChart extends StatelessWidget {
  const _ForecastBarChart({required this.points});

  final List<_ForecastPoint> points;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 300,
      child: BarChart(
        BarChartData(
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(show: true),
          titlesData: _bottomTitles(points.map((point) => point.label).toList()),
          barGroups: [
            for (var i = 0; i < points.length; i++)
              BarChartGroupData(x: i, barRods: [BarChartRodData(toY: points[i].value, color: Colors.blue, width: 24, borderRadius: BorderRadius.circular(4))])
          ],
        ),
      ),
    );
  }
}

LineChartBarData _line(List<MonthlyMetric> data, String label, Color color) {
  return LineChartBarData(
    spots: [for (var i = 0; i < data.length; i++) FlSpot(i.toDouble(), _metricValue(data[i], label))],
    isCurved: true,
    color: color,
    barWidth: 3,
    dotData: const FlDotData(show: false),
  );
}

double _metricValue(MonthlyMetric row, String label) {
  return switch (label) {
    'Loans' => row.loans,
    'Recovered' => row.recovered,
    'Repayment' => row.repayment,
    'Profit' => row.profit,
    _ => row.loans,
  };
}

FlTitlesData _bottomTitles(List<String> labels) {
  return FlTitlesData(
    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    bottomTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 36,
        getTitlesWidget: (value, meta) {
          final index = value.toInt();
          return Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(index >= 0 && index < labels.length ? labels[index] : '', style: const TextStyle(fontSize: 10)),
          );
        },
      ),
    ),
  );
}

class _LoanTile extends StatelessWidget {
  const _LoanTile({required this.loan});

  final LoanRecord loan;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(backgroundColor: Color(loan.risk.colorHex), child: Text('${loan.riskScore}', style: const TextStyle(color: Colors.white, fontSize: 12))),
      title: Text(loan.client, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text('${loan.item}\nDue ${dateInputValue(loan.dueDate).ifEmpty('missing')} - ${loan.risk.label}'),
      isThreeLine: true,
      trailing: Text(moneyFormat.format(loan.remaining), style: const TextStyle(fontWeight: FontWeight.w900)),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    return ListTile(contentPadding: EdgeInsets.zero, title: Text(label), trailing: Text(moneyFormat.format(value), style: const TextStyle(fontWeight: FontWeight.w900)));
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 110, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800))),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _EmptyChart extends StatelessWidget {
  const _EmptyChart();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(height: 180, child: Center(child: Text('No chart data available.')));
  }
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
