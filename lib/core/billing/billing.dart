import '../../models/api_models.dart';

String money(dynamic value) => '₹${asDouble(value).toStringAsFixed(2)}';
String percent(dynamic value) =>
    asDouble(value).toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');

/// Tax values come from the server; never recalculate the payable amount.
List<({String label, double amount})> taxLines(
  Json values, {
  bool invoice = false,
}) {
  final suffix = invoice ? '_amount' : '';
  final gst = asDouble(values[invoice ? 'gst_amount' : 'gst']);
  if (gst <= 0) return [];
  final rate = asDouble(values['gst_percent']);
  final cgst = values['cgst$suffix'];
  final sgst = values['sgst$suffix'];
  final igst = values['igst$suffix'];
  if (asDouble(cgst) > 0) {
    return [
      (label: 'CGST (${percent(rate / 2)}%)', amount: asDouble(cgst)),
      (label: 'SGST (${percent(rate / 2)}%)', amount: asDouble(sgst)),
    ];
  }
  if (asDouble(igst) > 0) {
    return [(label: 'IGST (${percent(rate)}%)', amount: asDouble(igst))];
  }
  return [(label: 'GST (${percent(rate)}%)', amount: gst)];
}
