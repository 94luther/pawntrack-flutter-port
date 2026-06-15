import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/pawntrack_models.dart';
import '../widgets/stat_card.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, required this.model});

  final PawnTrackModel model;

  @override
  Widget build(BuildContext context) {
    final cards = [
      StatCard(label: 'Principal', value: moneyFormat.format(model.principalOutstanding), tone: Colors.blue),
      StatCard(label: 'Expected repayment', value: moneyFormat.format(model.expectedRepayment), tone: Colors.green),
      StatCard(label: 'Inventory value', value: moneyFormat.format(model.inventoryValue), tone: Colors.orange),
      StatCard(label: 'Sales earned', value: moneyFormat.format(model.salesEarned), tone: Colors.teal),
      StatCard(label: 'Expected interest', value: moneyFormat.format(model.expectedInterest), tone: Colors.indigo),
      StatCard(label: 'Overdue loans', value: '${model.overdue.length}', tone: Colors.red),
    ];
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Wrap(spacing: 12, runSpacing: 12, children: cards.map((card) => SizedBox(width: 220, child: card)).toList()),
        const SizedBox(height: 18),
        _Panel(
          title: 'Financial Position',
          child: SizedBox(
            height: 280,
            child: BarChart(
              BarChartData(
                borderData: FlBorderData(show: false),
                gridData: const FlGridData(show: true),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final labels = ['Principal', 'Expected', 'Inventory', 'Sales'];
                        final index = value.toInt();
                        return Text(index >= 0 && index < labels.length ? labels[index] : '', style: const TextStyle(fontSize: 11));
                      },
                    ),
                  ),
                ),
                barGroups: [
                  _bar(0, model.principalOutstanding, Colors.blue),
                  _bar(1, model.expectedRepayment, Colors.green),
                  _bar(2, model.inventoryValue, Colors.orange),
                  _bar(3, model.salesEarned, Colors.teal),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        _Panel(
          title: 'Collections Snapshot',
          child: Column(
            children: model.overdue.take(8).map((loan) {
              return ListTile(
                dense: true,
                leading: CircleAvatar(backgroundColor: Color(loan.risk.colorHex), child: Text('${loan.riskScore}', style: const TextStyle(color: Colors.white, fontSize: 12))),
                title: Text(loan.client),
                subtitle: Text('${loan.type} - ${loan.item}'),
                trailing: Text(moneyFormat.format(loan.remaining), style: const TextStyle(fontWeight: FontWeight.w800)),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  BarChartGroupData _bar(int x, double value, Color color) {
    return BarChartGroupData(x: x, barRods: [BarChartRodData(toY: value, color: color, width: 24, borderRadius: BorderRadius.circular(4))]);
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
