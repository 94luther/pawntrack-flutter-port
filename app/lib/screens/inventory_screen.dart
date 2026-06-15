import 'package:flutter/material.dart';

import '../models/pawntrack_models.dart';
import '../widgets/stat_card.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({
    super.key,
    required this.model,
    required this.selectedInventoryId,
    required this.onSelectInventory,
    required this.onMarkSold,
    required this.writeStatus,
  });

  final PawnTrackModel model;
  final String? selectedInventoryId;
  final ValueChanged<String> onSelectInventory;
  final Future<void> Function(InventoryRecord item, String sellPrice, String pawnedAmount) onMarkSold;
  final String writeStatus;

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final sellPriceController = TextEditingController();
  final pawnedController = TextEditingController();

  @override
  void dispose() {
    sellPriceController.dispose();
    pawnedController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.model.availableInventory.where((item) => item.id == widget.selectedInventoryId).firstOrNull ?? widget.model.availableInventory.firstOrNull;
    if (selected != null && sellPriceController.text.isEmpty) sellPriceController.text = selected.value.round().toString();
    if (selected != null && pawnedController.text.isEmpty && selected.pawnAmount > 0) pawnedController.text = selected.pawnAmount.round().toString();
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Inventory', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 14),
        Wrap(spacing: 12, runSpacing: 12, children: [
          SizedBox(width: 220, child: StatCard(label: 'Available', value: moneyFormat.format(widget.model.inventoryValue), tone: Colors.orange)),
          SizedBox(width: 220, child: StatCard(label: 'Sales earned', value: moneyFormat.format(widget.model.salesEarned), tone: Colors.green)),
          SizedBox(width: 220, child: StatCard(label: 'Sales profit', value: moneyFormat.format(widget.model.salesProfit), tone: Colors.teal)),
          SizedBox(width: 220, child: StatCard(label: 'Sold items', value: '${widget.model.soldInventory.length}', tone: Colors.indigo)),
        ]),
        const SizedBox(height: 18),
        LayoutBuilder(builder: (context, constraints) {
          final editor = _SaleEditor(
            item: selected,
            sellPriceController: sellPriceController,
            pawnedController: pawnedController,
            writeStatus: widget.writeStatus,
            onSelectInventory: (id) {
              final next = widget.model.availableInventory.firstWhere((item) => item.id == id);
              widget.onSelectInventory(id);
              sellPriceController.text = next.value.round().toString();
              pawnedController.text = next.pawnAmount > 0 ? next.pawnAmount.round().toString() : '';
            },
            items: widget.model.availableInventory,
            onMarkSold: () async {
              if (selected == null) return;
              await widget.onMarkSold(selected, sellPriceController.text, pawnedController.text);
              sellPriceController.clear();
            },
          );
          final log = _SalesLog(items: widget.model.soldInventory);
          return constraints.maxWidth >= 860
              ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 420, child: editor), const SizedBox(width: 16), Expanded(child: log)])
              : Column(children: [editor, const SizedBox(height: 16), log]);
        }),
      ],
    );
  }
}

class _SaleEditor extends StatelessWidget {
  const _SaleEditor({
    required this.item,
    required this.items,
    required this.sellPriceController,
    required this.pawnedController,
    required this.writeStatus,
    required this.onSelectInventory,
    required this.onMarkSold,
  });

  final InventoryRecord? item;
  final List<InventoryRecord> items;
  final TextEditingController sellPriceController;
  final TextEditingController pawnedController;
  final String writeStatus;
  final ValueChanged<String> onSelectInventory;
  final VoidCallback onMarkSold;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xffe5e7eb))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Mark Inventory Sold', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: item?.id,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Item', border: OutlineInputBorder()),
            items: items.map((item) => DropdownMenuItem(value: item.id, child: Text('${item.product} - listed ${moneyFormat.format(item.value)}'))).toList(),
            onChanged: (id) {
              if (id != null) onSelectInventory(id);
            },
          ),
          const SizedBox(height: 10),
          TextField(controller: sellPriceController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Sell price', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(controller: pawnedController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Pawned for', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          if (item != null)
            Text('Expected repayment: ${item!.expectedRepayment == 0 ? 'missing' : moneyFormat.format(item!.expectedRepayment)}\nDate given: ${dateInputValue(item!.dateGiven).isEmpty ? 'missing' : dateInputValue(item!.dateGiven)}\nDays held: ${item!.daysHeld ?? 'missing'}'),
          const SizedBox(height: 12),
          FilledButton.icon(onPressed: item == null ? null : onMarkSold, icon: const Icon(Icons.sell), label: const Text('Mark Sold')),
          const SizedBox(height: 10),
          Text(writeStatus),
        ],
      ),
    );
  }
}

class _SalesLog extends StatelessWidget {
  const _SalesLog({required this.items});

  final List<InventoryRecord> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xffe5e7eb))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Sales Log', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          ...items.take(20).map((item) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(item.product, style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text('${item.pawnAmountSource}\nPawned ${moneyFormat.format(item.pawnAmount)} - Listed ${moneyFormat.format(item.value)} - Days held ${item.daysHeld ?? 'missing'}'),
                isThreeLine: true,
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(moneyFormat.format(item.sold), style: const TextStyle(fontWeight: FontWeight.w900)),
                    Text('Profit ${moneyFormat.format(item.profit)}'),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
