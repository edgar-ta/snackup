import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:snackup/theme/app_colors.dart';
import 'package:snackup/theme/app_text.dart';

enum DateRangeOption { lastWeek, lastMonth, allTime }

class StatisticsScreen extends StatefulWidget {
  final String businessId;
  const StatisticsScreen({super.key, required this.businessId});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  late Stream<QuerySnapshot> _completedOrdersStream;
  DateRangeOption _selectedRange = DateRangeOption.lastWeek;

  @override
  void initState() {
    super.initState();
    _completedOrdersStream = FirebaseFirestore.instance
        .collection('orders')
        .where('businessId', isEqualTo: widget.businessId)
        .where('status', isEqualTo: 'completed')
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Estadísticas',
          style: AppText.h3.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _completedOrdersStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _buildErrorState();
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingState();
          }
          if (snapshot.data!.docs.isEmpty) {
            return _buildEmptyState();
          }

          final docs = snapshot.data!.docs;
          // 1. Filtramos los documentos según el rango seleccionado
          final filteredDocs = _filterDocsByDateRange(docs, _selectedRange);

          // 2. Si el filtro deja la lista vacía, mostramos el selector y el estado vacío
          if (filteredDocs.isEmpty) {
            return Column(
              children: [
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildDateRangeSelector(),
                ),
                Expanded(child: _buildEmptyRangeState()),
              ],
            );
          }

          // 3. Cálculos basados en los documentos ya filtrados
          final double totalRevenue = _calculateTotalRevenue(filteredDocs);
          final int totalOrders = filteredDocs.length;
          final Map<String, int> paymentMethods = _calculatePaymentMethods(filteredDocs);
          final Map<String, int> topItems = _calculateTopItems(filteredDocs);
          final Map<int, double> salesByDay = _calculateSalesByDay(filteredDocs);

          final String salesTitle = _selectedRange == DateRangeOption.lastWeek
              ? 'Ventas - Últimos 7 Días'
              : _selectedRange == DateRangeOption.lastMonth
                  ? 'Ventas - Últimos 30 Días'
                  : 'Ventas - Todo el tiempo';
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDateRangeSelector(),
                const SizedBox(height: 24),
                // TARJETA DE INGRESOS PRINCIPAL
                _buildRevenueCard(totalRevenue, totalOrders),

                const SizedBox(height: 24),

                // GRÁFICA DE VENTAS POR DÍA
                _buildChartSection(
                  title: salesTitle,
                  subtitle: 'Distribución de ingresos por día de la semana',
                  child: _buildSalesByDayChart(salesByDay),
                ),

                const SizedBox(height: 24),

                // TOP PRODUCTOS
                _buildChartSection(
                  title: 'Productos Más Vendidos',
                  subtitle: 'Top 5 productos por cantidad vendida',
                  child: _buildTopItemsChart(topItems),
                ),

                const SizedBox(height: 24),

                // MÉTODOS DE PAGO
                _buildChartSection(
                  title: 'Métodos de Pago',
                  subtitle: 'Distribución de métodos de pago utilizados',
                  child: _buildPaymentChart(paymentMethods),
                ),

                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bar_chart_rounded,
              size: 64,
              color: AppColors.error.withOpacity(0.7),
            ),
            const SizedBox(height: 16),
            Text(
              'Error al cargar estadísticas',
              style: AppText.h3.copyWith(
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Verifica tu conexión e intenta nuevamente',
              style: AppText.body.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: AppColors.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'Cargando estadísticas...',
            style: AppText.body.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: AppColors.componentBase,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.analytics_rounded,
                size: 50,
                color: AppColors.textSecondary.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Aún no tienes estadísticas',
              style: AppText.h3.copyWith(
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Los datos aparecerán aquí una vez que completes tus primeros pedidos',
              style: AppText.body.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRevenueCard(double totalRevenue, int totalOrders) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.accent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ingresos Totales',
                    style: AppText.body.copyWith(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '\$${totalRevenue.toStringAsFixed(2)}',
                    style: AppText.h1.copyWith(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.attach_money_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Pedidos Completados:',
                  style: AppText.notes.copyWith(
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
                Text(
                  totalOrders.toString(),
                  style: AppText.body.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartSection({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.borders,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppText.h3.copyWith(
              color: AppColors.textPrimary,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: AppText.notes.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildSalesByDayChart(Map<int, double> salesByDay) {
    final maxSales = salesByDay.values.reduce((a, b) => a > b ? a : b);
    
    final List<BarChartGroupData> barGroups = List.generate(7, (index) {
      final day = index + 1;
      final sales = salesByDay[day] ?? 0.0;
      final isToday = day == DateTime.now().weekday;
      
      return BarChartGroupData(
        x: day,
        barRods: [
          BarChartRodData(
            toY: sales,
            color: isToday ? AppColors.accent : AppColors.primary,
            width: 20,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(6),
              topRight: Radius.circular(6),
            ),
            gradient: _createBarGradient(isToday ? AppColors.accent : AppColors.primary),
          )
        ],
        showingTooltipIndicators: sales > 0 ? [0] : [],
      );
    });

    return SizedBox(
      height: 250,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxSales * 1.2,
          minY: 0,
          barGroups: barGroups,
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  const style = TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  );
                  String text;
                  switch (value.toInt()) {
                    case 1: text = 'Lun'; break;
                    case 2: text = 'Mar'; break;
                    case 3: text = 'Mié'; break;
                    case 4: text = 'Jue'; break;
                    case 5: text = 'Vie'; break;
                    case 6: text = 'Sáb'; break;
                    case 7: text = 'Dom'; break;
                    default: text = ''; break;
                  }
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    child: Text(text, style: style),
                  );
                },
                reservedSize: 30,
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  if (value == 0) return const SizedBox.shrink();
                  return Text(
                    '\$${value.toInt()}',
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  );
                },
                interval: maxSales > 0 ? (maxSales / 4).ceilToDouble() : 1,
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border.all(
              color: AppColors.borders,
              width: 1,
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            drawHorizontalLine: true,
            horizontalInterval: maxSales > 0 ? (maxSales / 4).ceilToDouble() : 1,
            getDrawingHorizontalLine: (value) => FlLine(
              color: AppColors.borders.withOpacity(0.3),
              strokeWidth: 1,
            ),
          ),
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              // CORRECCIÓN APLICADA AQUÍ PARA COMPATIBILIDAD CON LA LIBRERÍA
              tooltipBgColor: AppColors.textPrimary,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                return BarTooltipItem(
                  '\$${rod.toY.toStringAsFixed(2)}',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopItemsChart(Map<String, int> topItems) {
    if (topItems.isEmpty) return _buildNoDataPlaceholder();

    final sortedItems = topItems.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top5Items = sortedItems.take(5).toList();
    final maxValue = top5Items.first.value.toDouble();

    final List<BarChartGroupData> barGroups = List.generate(top5Items.length, (index) {
      final item = top5Items[index];
      // final percentage = (item.value / maxValue * 100).round(); // no se usa
      
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: item.value.toDouble(),
            color: _getProductColor(index),
            width: 28,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(6),
              topRight: Radius.circular(6),
            ),
            gradient: _createBarGradient(_getProductColor(index)),
          )
        ],
        showingTooltipIndicators: [0],
      );
    });

    return SizedBox(
      height: 250,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxValue * 1.2,
          minY: 0,
          barGroups: barGroups,
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  if (value.toInt() >= top5Items.length) return const SizedBox.shrink();
                  final item = top5Items[value.toInt()];
                  final shortName = item.key.length > 12 
                      ? '${item.key.substring(0, 12)}...' 
                      : item.key;
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    child: Text(
                      shortName,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  );
                },
                reservedSize: 60,
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  if (value == 0) return const SizedBox.shrink();
                  return Text(
                    value.toInt().toString(),
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  );
                },
                interval: maxValue > 0 ? (maxValue / 4).ceilToDouble() : 1,
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border.all(
              color: AppColors.borders,
              width: 1,
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            drawHorizontalLine: true,
            horizontalInterval: maxValue > 0 ? (maxValue / 4).ceilToDouble() : 1,
            getDrawingHorizontalLine: (value) => FlLine(
              color: AppColors.borders.withOpacity(0.3),
              strokeWidth: 1,
            ),
          ),
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              // CORRECCIÓN APLICADA AQUÍ TAMBIÉN
              tooltipBgColor: AppColors.textPrimary,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final item = top5Items[groupIndex];
                return BarTooltipItem(
                  '${item.key}\n${item.value} vendidos',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentChart(Map<String, int> paymentMethods) {
    if (paymentMethods.isEmpty) return _buildNoDataPlaceholder();
    
    final total = paymentMethods.values.reduce((a, b) => a + b);
    final List<PieChartSectionData> sections = [];
    final List<Color> colors = [
      AppColors.primary,
      AppColors.accent,
      AppColors.tertiary,
      AppColors.success,
      AppColors.warning,
    ];

    int colorIndex = 0;
    for (var entry in paymentMethods.entries) {
      final percentage = ((entry.value / total) * 100).round();
      sections.add(
        PieChartSectionData(
          value: entry.value.toDouble(),
          title: '$percentage%',
          radius: 60,
          color: colors[colorIndex % colors.length],
          titleStyle: AppText.notes.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      );
      colorIndex++;
    }

    return Column(
      children: [
        SizedBox(
          height: 200,
          child: PieChart(
            PieChartData(
              sections: sections,
              sectionsSpace: 2,
              centerSpaceRadius: 50,
              pieTouchData: PieTouchData(
                touchCallback: (FlTouchEvent event, pieTouchResponse) {},
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildPaymentLegend(paymentMethods, colors),
      ],
    );
  }

  Widget _buildPaymentLegend(Map<String, int> paymentMethods, List<Color> colors) {
    final total = paymentMethods.values.reduce((a, b) => a + b);
    int colorIndex = 0;

    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: paymentMethods.entries.map((entry) {
        final percentage = ((entry.value / total) * 100).round();
        final color = colors[colorIndex % colors.length];
        colorIndex++;
        
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '${entry.key} ($percentage%)',
              style: AppText.notes.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildNoDataPlaceholder() {
    return Container(
      height: 150,
      decoration: BoxDecoration(
        color: AppColors.componentBase,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bar_chart_rounded,
              size: 40,
              color: AppColors.textSecondary.withOpacity(0.4),
            ),
            const SizedBox(height: 8),
            Text(
              'No hay datos disponibles',
              style: AppText.notes.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  LinearGradient _createBarGradient(Color baseColor) {
    return LinearGradient(
      colors: [
        baseColor,
        baseColor.withOpacity(0.7),
      ],
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
    );
  }

  Color _getProductColor(int index) {
    final colors = [
      AppColors.primary,
      AppColors.accent,
      AppColors.tertiary,
      AppColors.success,
      AppColors.warning,
    ];
    return colors[index % colors.length];
  }

  // --- FUNCIONES DE CÁLCULO ---
  Widget _buildDateRangeSelector() {
    return Wrap(
      spacing: 8,
      children: DateRangeOption.values.map((range) {
        final selected = _selectedRange == range;
        return ChoiceChip(
          label: Text(_getRangeLabel(range)),
          selected: selected,
          selectedColor: AppColors.primary,
          backgroundColor: AppColors.componentBase,
          labelStyle: AppText.body.copyWith(
            color: selected ? Colors.white : AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          onSelected: (_) {
            setState(() {
              _selectedRange = range;
            });
          },
        );
      }).toList(),
    );
  }

  Widget _buildEmptyRangeState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.calendar_month_rounded,
              size: 64,
              color: AppColors.textSecondary.withOpacity(0.6),
            ),
            const SizedBox(height: 16),
            Text(
              'No hay datos en este rango',
              style: AppText.h3.copyWith(color: AppColors.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Selecciona otro rango para ver estadísticas.',
              style: AppText.body.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  String _getRangeLabel(DateRangeOption range) {
    switch (range) {
      case DateRangeOption.lastWeek:
        return 'Última semana';
      case DateRangeOption.lastMonth:
        return 'Último mes';
      case DateRangeOption.allTime:
        return 'Todo el tiempo';
    }
  }

  DateTime _getRangeStart(DateRangeOption range) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (range) {
      case DateRangeOption.lastWeek:
        return today.subtract(const Duration(days: 6));
      case DateRangeOption.lastMonth:
        return today.subtract(const Duration(days: 29));
      case DateRangeOption.allTime:
        return DateTime.fromMillisecondsSinceEpoch(0);
    }
  }

  List<QueryDocumentSnapshot> _filterDocsByDateRange(
    List<QueryDocumentSnapshot> docs,
    DateRangeOption range,
  ) {
    if (range == DateRangeOption.allTime) return docs;

    final start = _getRangeStart(range);
    final now = DateTime.now();

    return docs.where((doc) {
      final timestamp = doc['createdAt'] as Timestamp?;
      if (timestamp == null) return false;
      final date = timestamp.toDate();
      return !date.isBefore(start) && !date.isAfter(now);
    }).toList();
  }

  // --- FUNCIONES DE CÁLCULO (Sin cambios) ---
  double _calculateTotalRevenue(List<QueryDocumentSnapshot> docs) {
    double total = 0.0;
    for (var doc in docs) {
      total += (doc['totalPrice'] as num?)?.toDouble() ?? 0.0;
    }
    return total;
  }

  Map<String, int> _calculatePaymentMethods(List<QueryDocumentSnapshot> docs) {
    Map<String, int> counts = {};
    for (var doc in docs) {
      String method = (doc['paymentMethod'] as String?) ?? 'Desconocido';
      counts[method] = (counts[method] ?? 0) + 1;
    }
    return counts;
  }

  Map<String, int> _calculateTopItems(List<QueryDocumentSnapshot> docs) {
    Map<String, int> counts = {};
    for (var doc in docs) {
      List<dynamic> items = (doc['items'] as List<dynamic>?) ?? [];
      for (var item in items) {
        if (item is Map) {
          String name = (item['name'] as String?) ?? 'Producto';
          int quantity = (item['quantity'] as num?)?.toInt() ?? 0;
          counts[name] = (counts[name] ?? 0) + quantity;
        }
      }
    }
    return counts;
  }
  
  Map<int, double> _calculateSalesByDay(List<QueryDocumentSnapshot> docs) {
    // Inicializamos los 7 días de la semana en 0 (1=Lunes, 7=Domingo)
    Map<int, double> dailySales = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0, 7: 0};
    
    for (var doc in docs) {
      final timestamp = doc['createdAt'] as Timestamp?;
      final price = (doc['totalPrice'] as num?)?.toDouble() ?? 0.0;
      
      if (timestamp != null) {
        final date = timestamp.toDate();
        // Sumamos el precio al día de la semana correspondiente
        dailySales[date.weekday] = (dailySales[date.weekday] ?? 0) + price;
      }
    }
    return dailySales;
  }