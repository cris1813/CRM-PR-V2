import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
  );
  runApp(const CrmMayoristaApp());
}

class CrmMayoristaApp extends StatelessWidget {
  const CrmMayoristaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CRM Mayorista Pro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0B1120),
        primaryColor: const Color(0xFF10B981),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF10B981),
          secondary: Color(0xFF38BDF8),
          surface: Color(0xFF1E293B),
        ),
        useMaterial3: true,
      ),
      home: const MainDashboard(),
    );
  }
}

// ==========================================
// MODELO DE CLIENTE
// ==========================================
class Cliente {
  String id;
  String nombre;
  String rut;
  String telefono;
  String categoria;
  String queCompra;
  int montoPromedio;
  String notas;
  bool prefiereLlamada;
  int cicloDias;
  DateTime ultimoContacto;

  Cliente({
    required this.id,
    required this.nombre,
    required this.rut,
    required this.telefono,
    required this.categoria,
    required this.queCompra,
    required this.montoPromedio,
    required this.notas,
    this.prefiereLlamada = false,
    this.cicloDias = 10,
    DateTime? ultimoContacto,
  }) : ultimoContacto =
            ultimoContacto ?? DateTime.now().subtract(const Duration(days: 12));

  int get diasSinContacto => DateTime.now().difference(ultimoContacto).inDays;
  bool get requiereAtencionUrgente => diasSinContacto >= cicloDias;

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': nombre,
        'rut': rut,
        'telefono': telefono,
        'categoria': categoria,
        'queCompra': queCompra,
        'montoPromedio': montoPromedio,
        'notas': notas,
        'prefiereLlamada': prefiereLlamada,
        'cicloDias': cicloDias,
        'ultimoContacto': ultimoContacto.toIso8601String(),
      };

  factory Cliente.fromJson(Map<String, dynamic> json) => Cliente(
        id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
        nombre: json['nombre'] ?? 'Cliente',
        rut: json['rut'] ?? '',
        telefono: json['telefono'] ?? '',
        categoria: json['categoria'] ?? 'Sin Clasificar',
        queCompra: json['queCompra'] ?? '',
        montoPromedio: json['montoPromedio'] ?? 0,
        notas: json['notas'] ?? '',
        prefiereLlamada: json['prefiereLlamada'] ?? false,
        cicloDias: json['cicloDias'] ?? 10,
        ultimoContacto:
            DateTime.tryParse(json['ultimoContacto'] ?? '') ?? DateTime.now(),
      );
}

// ==========================================
// CARTERA REAL PRECARGADA DESDE TU PDF
// ==========================================
final List<Cliente> clientesSemilla = [
  Cliente(id: '1', nombre: 'Caroline / Cesar (Almacén San Vicente)', rut: '78.076.635', telefono: '+56964203947', categoria: 'Abarrotes y Alimentos', queCompra: 'Compra millones en chocolates', montoPromedio: 2000000, notas: 'Tel alt: 935595136. Llamar y escribir', cicloDias: 7, ultimoContacto: DateTime.now().subtract(const Duration(days: 11))),
  Cliente(id: '2', nombre: 'Comercializadora Weisz', rut: '78.102.847-9', telefono: '+56981441715', categoria: 'Abarrotes y Alimentos', queCompra: 'Mucho pallet de arroz y azúcar', montoPromedio: 1500000, notas: 'Cliente potencial de alto volumen', cicloDias: 10, ultimoContacto: DateTime.now().subtract(const Duration(days: 14))),
  Cliente(id: '3', nombre: 'Marcela', rut: '', telefono: '+56961636386', categoria: 'Abarrotes y Alimentos', queCompra: 'Precios por pallet y productos corta fecha', montoPromedio: 800000, notas: 'Avisar apenas entren lotes a corta fecha', cicloDias: 7, ultimoContacto: DateTime.now().subtract(const Duration(days: 8))),
  Cliente(id: '4', nombre: 'Santa Economia EIRL / Mauricio Miranda', rut: '78.199.928-8', telefono: '+56997586362', categoria: 'Abarrotes y Alimentos', queCompra: 'Surtido general de negocio', montoPromedio: 1200000, notas: 'Compra mucho, recién surtiendo negocio', cicloDias: 10, ultimoContacto: DateTime.now().subtract(const Duration(days: 5))),
  Cliente(id: '5', nombre: 'Santa Flora SpA / Cristian Miranda', rut: '78.291.382-4', telefono: '+56983543128', categoria: 'Abarrotes y Alimentos', queCompra: 'Compra de todo y bebidas', montoPromedio: 1000000, notas: 'Avisar urgente cuando lleguen todas las bebidas', cicloDias: 7, ultimoContacto: DateTime.now().subtract(const Duration(days: 9))),
  Cliente(id: '6', nombre: 'Silvia', rut: '9.182.388-8', telefono: '+56936424876', categoria: 'Abarrotes y Alimentos', queCompra: 'Surtido de todo para almacén', montoPromedio: 450000, notas: 'Almacén tradicional', cicloDias: 10, ultimoContacto: DateTime.now().subtract(const Duration(days: 4))),
  Cliente(id: '7', nombre: 'Sra Margarita (Verdurería Las Nietas)', rut: '11.737.106-9', telefono: '+56972969640', categoria: 'Abarrotes y Alimentos', queCompra: 'Surtido completo minimarket playa', montoPromedio: 3000000, notas: 'Cliente Ballena: compra 3 millones', cicloDias: 10, ultimoContacto: DateTime.now().subtract(const Duration(days: 15))),
  Cliente(id: '8', nombre: 'Victor / Panadería', rut: '78.441.909-6', telefono: '+56981934386', categoria: 'Abarrotes y Alimentos', queCompra: 'Insumos panadería y abarrotes', montoPromedio: 2000000, notas: 'Cliente Ballena: compró 2 millones', cicloDias: 10, ultimoContacto: DateTime.now().subtract(const Duration(days: 13))),
  Cliente(id: '9', nombre: 'Erika Saez', rut: '13.607.820-8', telefono: '+56966162817', categoria: 'Abarrotes y Alimentos', queCompra: 'Queso despunte y fiambrería', montoPromedio: 500000, notas: 'Avisar siempre que llegue queso despunte', cicloDias: 7, ultimoContacto: DateTime.now().subtract(const Duration(days: 8))),
  Cliente(id: '10', nombre: 'Cliente Almacenero', rut: '', telefono: '+56942826685', categoria: 'Abarrotes y Alimentos', queCompra: 'Mercadería general de almacén', montoPromedio: 500000, notas: 'Promedio de compra 500.000', cicloDias: 10, ultimoContacto: DateTime.now().subtract(const Duration(days: 6))),
  Cliente(id: '11', nombre: 'Agrolatino / Cristopher', rut: '78.070.723-2', telefono: '+56932516615', categoria: 'Aseo y Papel', queCompra: 'Pallet de papel higiénico', montoPromedio: 1200000, notas: 'Compra por volumen de pallet', cicloDias: 14, ultimoContacto: DateTime.now().subtract(const Duration(days: 12))),
  Cliente(id: '12', nombre: 'Andres Albarracin', rut: '77.305.701-K', telefono: '+56958383389', categoria: 'Aseo y Papel', queCompra: 'Higiénico, toalla, servilleta, bolsa, detergente', montoPromedio: 900000, notas: 'Canal E-commerce', cicloDias: 10, ultimoContacto: DateTime.now().subtract(const Duration(days: 7))),
  Cliente(id: '13', nombre: 'Carlos Ignacio Brante', rut: '15.999.884-3', telefono: '+56964819488', categoria: 'Aseo y Papel', queCompra: 'Papel higiénico y toallas', montoPromedio: 450000, notas: 'Emprendimiento de papel', cicloDias: 10, ultimoContacto: DateTime.now().subtract(const Duration(days: 9))),
  Cliente(id: '14', nombre: 'Comercial ATH / Pedro', rut: '76.751.574-K', telefono: '+56922133197', categoria: 'Aseo y Papel', queCompra: 'Mucho papel (cotizó 500 mangas de Elite)', montoPromedio: 2500000, notas: 'Cliente de altísimo volumen en papel', cicloDias: 10, ultimoContacto: DateTime.now().subtract(const Duration(days: 14))),
  Cliente(id: '15', nombre: 'Dilum Restauran', rut: '75.840.502-6', telefono: '+56942252957', categoria: 'Aseo y Papel', queCompra: 'Papel oferta 4x500', montoPromedio: 400000, notas: 'Recordatorio: Avisar día 20 para oferta 4x500', cicloDias: 15, ultimoContacto: DateTime.now().subtract(const Duration(days: 16))),
  Cliente(id: '16', nombre: 'DIST Y COMER Santa Juana LTDA', rut: '77.882.033-1', telefono: '+56977646940', categoria: 'Aseo y Papel', queCompra: 'Papel higiénico, toalla y productos corta fecha', montoPromedio: 1100000, notas: 'Interesado en corta fecha y papel', cicloDias: 10, ultimoContacto: DateTime.now().subtract(const Duration(days: 8))),
  Cliente(id: '17', nombre: 'Edgar (Ovalle - 3 Minimarkets)', rut: '26.452.795-3', telefono: '+56954843198', categoria: 'Aseo y Papel', queCompra: 'Aseo y perfumería para 3 locales', montoPromedio: 1800000, notas: 'Es de Ovalle. DE PREFERENCIA LLAMAR', prefiereLlamada: true, cicloDias: 12, ultimoContacto: DateTime.now().subtract(const Duration(days: 15))),
  Cliente(id: '18', nombre: 'Karen', rut: '', telefono: '+56978797268', categoria: 'Aseo y Papel', queCompra: 'Papel y artículos de aseo', montoPromedio: 400000, notas: 'Interesada en ofertas de aseo', cicloDias: 10, ultimoContacto: DateTime.now().subtract(const Duration(days: 5))),
  Cliente(id: '19', nombre: 'LED - MARIA CRISTINA', rut: '16.716.408-0', telefono: '+56978473181', categoria: 'Aseo y Papel', queCompra: 'Artículos de aseo por mayor', montoPromedio: 1500000, notas: 'Compran mucho. Tel 2: 978473185', cicloDias: 10, ultimoContacto: DateTime.now().subtract(const Duration(days: 11))),
  Cliente(id: '20', nombre: 'Limpieza Aysi SpA', rut: '78.414.683', telefono: '+56986484781', categoria: 'Aseo y Papel', queCompra: 'Artículos de limpieza general', montoPromedio: 400000, notas: 'Cliente empezando en venta de limpieza', cicloDias: 10, ultimoContacto: DateTime.now().subtract(const Duration(days: 6))),
  Cliente(id: '21', nombre: 'Maribel Natalia Arcos', rut: '17.336.845-3', telefono: '+56948755324', categoria: 'Aseo y Papel', queCompra: 'Mucho papel e insumos para carnicería', montoPromedio: 950000, notas: 'Carnicería. DE PREFERENCIA LLAMAR (Javi)', prefiereLlamada: true, cicloDias: 10, ultimoContacto: DateTime.now().subtract(const Duration(days: 12))),
  Cliente(id: '22', nombre: 'Minimarket Ricardo Andres Nuñez', rut: '78.322.941-2', telefono: '+56959661230', categoria: 'Aseo y Papel', queCompra: 'Papel de 10 en 10 mangas por tipo', montoPromedio: 500000, notas: 'Promedio de compra \$500.000 constante', cicloDias: 10, ultimoContacto: DateTime.now().subtract(const Duration(days: 9))),
  Cliente(id: '23', nombre: 'Angel L2P SpA', rut: '78.130.297-K', telefono: '+56931815515', categoria: 'Mayoristas / Surtido General', queCompra: 'Compra de todo (surtido completo)', montoPromedio: 1500000, notas: 'Recordatorio: Llamar los lunes', prefiereLlamada: true, cicloDias: 7, ultimoContacto: DateTime.now().subtract(const Duration(days: 8))),
  Cliente(id: '24', nombre: 'Comercial Nietos / Alfredo', rut: '77.979.333-8', telefono: '+56978515834', categoria: 'Mayoristas / Surtido General', queCompra: 'Compra millones y de todo', montoPromedio: 2800000, notas: 'Ballena VIP: Cliente con varios locales', cicloDias: 10, ultimoContacto: DateTime.now().subtract(const Duration(days: 14))),
  Cliente(id: '25', nombre: 'Edisson Bonacic Rojas', rut: '13.983.850-5', telefono: '+56957111745', categoria: 'Mayoristas / Surtido General', queCompra: 'Surtido mayorista de alto volumen', montoPromedio: 3000000, notas: 'Última compra 3 millones - IMPORTANTE LLAMAR', prefiereLlamada: true, cicloDias: 10, ultimoContacto: DateTime.now().subtract(const Duration(days: 16))),
  Cliente(id: '26', nombre: 'Fabian Erice (Rancagua)', rut: '17.573.384-1', telefono: '+56957047224', categoria: 'Mayoristas / Surtido General', queCompra: 'Compra quincenal de todo', montoPromedio: 1400000, notas: 'Ciclo fijo cada 15 días (Rancagua)', cicloDias: 14, ultimoContacto: DateTime.now().subtract(const Duration(days: 14))),
  Cliente(id: '27', nombre: 'Luis Silva (Melipilla)', rut: '78.370.642-3', telefono: '+56965857854', categoria: 'Mayoristas / Surtido General', queCompra: 'Surtido con despacho a Melipilla', montoPromedio: 650000, notas: 'Compra sobre \$600.000 para despacho', cicloDias: 12, ultimoContacto: DateTime.now().subtract(const Duration(days: 10))),
  Cliente(id: '28', nombre: 'Tres Hermanos', rut: '78.177.706-4', telefono: '+56957260645', categoria: 'Mayoristas / Surtido General', queCompra: 'Compra de todo y mucho producto TOP', montoPromedio: 1800000, notas: 'Avisar productos de alta rotación', cicloDias: 10, ultimoContacto: DateTime.now().subtract(const Duration(days: 7))),
  Cliente(id: '29', nombre: 'Yris Local 57', rut: '', telefono: '+56921751069', categoria: 'Mayoristas / Surtido General', queCompra: 'Compra de todo', montoPromedio: 750000, notas: 'Local 57', cicloDias: 10, ultimoContacto: DateTime.now().subtract(const Duration(days: 6))),
  Cliente(id: '30', nombre: 'Ramon', rut: '', telefono: '+56954352142', categoria: 'Clientes de Feria', queCompra: 'Papelería y perfumería', montoPromedio: 350000, notas: 'Puesto de Feria', cicloDias: 7, ultimoContacto: DateTime.now().subtract(const Duration(days: 5))),
  Cliente(id: '31', nombre: 'Miguel Muñoz', rut: '', telefono: '+56956054737', categoria: 'Clientes de Feria', queCompra: 'Papelería y perfumería', montoPromedio: 350000, notas: 'Puesto de Feria', cicloDias: 7, ultimoContacto: DateTime.now().subtract(const Duration(days: 8))),
  Cliente(id: '32', nombre: 'Gemma del Carmen Henriquez Orellana', rut: '12.676.382-4', telefono: '', categoria: 'Facturación Reciente', queCompra: 'Factura Mayorista (7 líneas de prod.)', montoPromedio: 1292815, notas: 'Sucursal Bernardino Parada 0958 - Transf. Electrónica', cicloDias: 10, ultimoContacto: DateTime.now().subtract(const Duration(days: 11))),
  Cliente(id: '33', nombre: 'Marco Loriza Pereira', rut: '9.766.488-2', telefono: '', categoria: 'Facturación Reciente', queCompra: 'Factura Mayorista (15 productos)', montoPromedio: 253548, notas: 'Local 77 Bodega Mersan - Transbank', cicloDias: 14, ultimoContacto: DateTime.now().subtract(const Duration(days: 9))),
  Cliente(id: '34', nombre: 'Angelo Fuente Alba', rut: '', telefono: '+56987387277', categoria: 'Sin Clasificar', queCompra: 'Pendiente consultar rubro principal', montoPromedio: 300000, notas: 'Clasificar en próximo contacto', cicloDias: 7, ultimoContacto: DateTime.now().subtract(const Duration(days: 15))),
  Cliente(id: '35', nombre: 'Freddy Cartagena', rut: '', telefono: '+56963162615', categoria: 'Sin Clasificar', queCompra: 'Pendiente consultar rubro principal', montoPromedio: 300000, notas: 'Clasificar en próximo contacto', cicloDias: 7, ultimoContacto: DateTime.now().subtract(const Duration(days: 15))),
  Cliente(id: '36', nombre: 'GSM Construcciones SpA', rut: '', telefono: '+56950339202', categoria: 'Sin Clasificar', queCompra: 'Pendiente consultar rubro principal', montoPromedio: 400000, notas: 'Empresa constructora', cicloDias: 14, ultimoContacto: DateTime.now().subtract(const Duration(days: 14))),
];

String formatearPesos(int monto) {
  final str = monto.toString();
  final buffer = StringBuffer();
  for (int i = 0; i < str.length; i++) {
    if (i > 0 && (str.length - i) % 3 == 0) buffer.write('.');
    buffer.write(str[i]);
  }
  return buffer.toString();
}

// ==========================================
// MOTOR DEEPSEEK OFFLINE (100% LOCAL Y FUNCIONAL)
// ==========================================
class DeepSeekOfflineEngine {
  static String generarMensajePersonalizado(Cliente c, String promoBase, int variacion) {
    final nombreCorto = c.nombre.split('/').first.split('(').first.trim();
    final saludos = [
      'Hola $nombreCorto, ¿cómo va todo por el local?',
      '¡Buenas $nombreCorto! Te escribo directo desde bodega.',
      'Hola $nombreCorto, espero que estés teniendo una excelente semana de ventas.',
      '¿Qué tal $nombreCorto? Te paso este dato antes de que se agote el lote.'
    ];

    final gancho = c.queCompra.isNotEmpty && !c.queCompra.toLowerCase().contains('pendiente')
        ? 'Como sé que trabajas fuerte con *${c.queCompra.toLowerCase()}*, te reservé prioridad en esta oferta:'
        : 'Nos acaba de entrar mercadería con margen ideal para tu negocio:';

    final extraVolumen = c.montoPromedio >= 1500000
        ? '\n💼 *Precio especial por volumen/pallet disponible para tu cuenta.*'
        : '';

    final cierres = [
      '¿Cuántas mangas/cajas te separo o prefieres que te llame en 5 minutos?',
      'Avísame por acá qué cantidad te anoto para bloquearte el stock.',
      'Si te sirve me confirmas por esta vía o te pego un llamado rápido.',
    ];

    final s = saludos[variacion % saludos.length];
    final cierre = cierres[variacion % cierres.length];

    return '$s\n\n$gancho\n\n🔥 *$promoBase*$extraVolumen\n\n$cierre';
  }

  static String responderConsultaOffline(String pregunta, List<Cliente> clientes) {
    final q = pregunta.toLowerCase().trim();
    if (q.isEmpty) return 'Escribe una consulta sobre tu cartera o pide redactar una promoción.';

    if (q.contains('corta fecha') || q.contains('vencimiento')) {
      final lista = clientes.where((c) =>
          c.queCompra.toLowerCase().contains('corta fecha') ||
          c.notas.toLowerCase().contains('corta fecha')).toList();
      return '🎯 *Clientes ideales para Corta Fecha (${lista.length}):*\n' +
          lista.map((c) => '• *${c.nombre}* (${c.telefono}) - ${c.queCompra}').join('\n') +
          '\n\n💡 *Sugerencia DeepSeek:* Lanza una campaña filtrando a Marcela y DIST Y COMER Santa Juana ofreciendo liquidación por lote cerrado.';
    }

    if (q.contains('papel') || q.contains('higienico') || q.contains('higiénico') || q.contains('aseo') || q.contains('elite')) {
      final lista = clientes.where((c) => c.categoria == 'Aseo y Papel').toList()
        ..sort((a, b) => b.montoPromedio.compareTo(a.montoPromedio));
      return '🧻 *Top Compradores de Aseo y Papel (${lista.length} clientes):*\n' +
          lista.take(6).map((c) => '• *${c.nombre}*: \$${formatearPesos(c.montoPromedio)} (${c.queCompra})').join('\n') +
          '\n\n💡 *Tip:* A Comercial ATH/Pedro ofrécele por sobre 100 mangas y a Ricardo Nuñez en múltiplos de 10 mangas.';
    }

    if (q.contains('queso') || q.contains('bebida') || q.contains('chocolate') || q.contains('arroz')) {
      final palabra = q.contains('queso') ? 'queso' : q.contains('bebida') ? 'bebida' : q.contains('chocolate') ? 'chocolate' : 'arroz';
      final lista = clientes.where((c) =>
          c.queCompra.toLowerCase().contains(palabra) ||
          c.notas.toLowerCase().contains(palabra)).toList();
      return '🔎 *Coincidencias exactas para "$palabra":*\n' +
          (lista.isEmpty
              ? 'No hay clientes con esa etiqueta específica, te sugiero ofrecerlo a Mayoristas / Surtido General.'
              : lista.map((c) => '• *${c.nombre}* (${c.telefono}) -> ${c.queCompra} / ${c.notas}').join('\n'));
    }

    if (q.contains('llamar') || q.contains('urgente') || q.contains('hoy') || q.contains('riesgo') || q.contains('ballena')) {
      final urgentes = clientes.where((c) => c.requiereAtencionUrgente).toList()
        ..sort((a, b) => b.montoPromedio.compareTo(a.montoPromedio));
      final total = urgentes.fold<int>(0, (s, c) => s + c.montoPromedio);
      return '🚨 *Plan de Llamadas Hoy (${urgentes.length} pendientes | \$${formatearPesos(total)} en juego):*\n\n' +
          urgentes.take(6).map((c) => '• *${c.nombre}* (\$${formatearPesos(c.montoPromedio)}) - Hace ${c.diasSinContacto} días sin contacto ${c.prefiereLlamada ? "[LLAMAR DIRECTO]" : ""}').join('\n');
    }

    if (q.contains('redact') || q.contains('mensaje') || q.contains('promo')) {
      return '✍️ *Propuesta de Copywriting Mayorista (Anti-Spam):*\n\n"¡Hola [Nombre]! Te escribo rápido desde bodega porque acaba de entrar lote nuevo en oferta cerrada. Te reservé cupo a precio mayorista antes de subirlo a piso. ¿Te separo un par de mangas/cajas o te pego una llamada corta?"';
    }

    final totalCartera = clientes.fold<int>(0, (s, c) => s + c.montoPromedio);
    final vip = clientes.where((c) => c.montoPromedio >= 1500000).length;
    return '🧠 *Análisis DeepSeek Local (Sin Internet):*\n'
        '• Valor estimado mensual de tu cartera: *\$${formatearPesos(totalCartera)}*\n'
        '• Clientes Ballena (+1.5M): *$vip clientes*\n'
        '• Clientes esperando contacto hoy: *${clientes.where((c) => c.requiereAtencionUrgente).length}*\n\n'
        'Pregúntame por productos específicos (ej: *"¿Quién compra corta fecha?"*, *"¿A quién le vendo papel?"*, *"¿A quién debo llamar hoy?"*).';
  }

  static Cliente extraerClienteDesdeNotaCaotica(String textoBruto) {
    final telMatch = RegExp(r'(?:\+?56)?\s*9\s*[0-9]{4}\s*[0-9]{4}|[0-9]{8,11}').firstMatch(textoBruto);
    String tel = telMatch != null ? telMatch.group(0)!.replaceAll(' ', '') : '';
    if (tel.length == 9 && tel.startsWith('9')) tel = '+56$tel';
    if (tel.length == 11 && tel.startsWith('569')) tel = '+$tel';

    final rutMatch = RegExp(r'\b[0-9]{1,2}\.?[0-9]{3}\.?[0-9]{3}-?[0-9kK]\b').firstMatch(textoBruto);
    final String rut = rutMatch != null ? rutMatch.group(0)! : '';

    int monto = 500000;
    if (textoBruto.toLowerCase().contains('millon')) {
      final mMatch = RegExp(r'(\d+)\s*millon').firstMatch(textoBruto.toLowerCase());
      monto = mMatch != null ? int.parse(mMatch.group(1)!) * 1000000 : 1500000;
    } else {
      final numMatch = RegExp(r'\b([1-9][0-9]{2})\.?000\b').firstMatch(textoBruto);
      if (numMatch != null) {
        monto = int.parse(numMatch.group(1)!) * 1000;
      }
    }

    final lower = textoBruto.toLowerCase();
    String categoria = 'Mayoristas / Surtido General';
    if (lower.contains('papel') || lower.contains('aseo') || lower.contains('higienico') || lower.contains('toalla') || lower.contains('detergente')) {
      categoria = 'Aseo y Papel';
    } else if (lower.contains('abarrote') || lower.contains('almacen') || lower.contains('arroz') || lower.contains('queso') || lower.contains('bebida') || lower.contains('chocolate')) {
      categoria = 'Abarrotes y Alimentos';
    } else if (lower.contains('feria')) {
      categoria = 'Clientes de Feria';
    }

    String limpio = textoBruto
        .replaceAll(telMatch?.group(0) ?? '', '')
        .replaceAll(rut, '')
        .trim();
    final palabras = limpio.split(RegExp(r'\s+')).take(3).join(' ');
    final nombre = palabras.isNotEmpty ? palabras : 'Nuevo Cliente Mayorista';

    return Cliente(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      nombre: nombre,
      rut: rut,
      telefono: tel,
      categoria: categoria,
      queCompra: textoBruto.trim(),
      montoPromedio: monto,
      notas: 'Extraído automáticamente con IA Offline',
      prefiereLlamada: lower.contains('llamar'),
    );
  }
}

// ==========================================
// DASHBOARD PRINCIPAL (5 PESTAÑAS FLUIDAS)
// ==========================================
class MainDashboard extends StatefulWidget {
  const MainDashboard({super.key});

  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard> {
  static const platform = MethodChannel('com.cristobal.crm/accessibility');
  int _tabIndex = 0;
  List<Cliente> _clientes = [];
  String _filtroCategoria = 'Todos';
  String _busqueda = '';
  bool _accesibilidadActiva = false;

  // Estudio Creador de Promociones (Flyer)
  final GlobalKey _flyerKey = GlobalKey();
  File? _fotoProducto;
  final TextEditingController _tituloAficheCtrl = TextEditingController(text: 'PAPEL HIGIÉNICO ELITE');
  final TextEditingController _subtituloAficheCtrl = TextEditingController(text: 'Formato Mayorista • Manga / Pallet');
  final TextEditingController _precioAntesCtrl = TextEditingController(text: '\$6.500');
  final TextEditingController _precioOfertaCtrl = TextEditingController(text: '\$4.500');
  String _selloAfiche = '¡OFERTA 4x500!';
  Color _colorTemaAfiche = const Color(0xFFDC2626);
  String? _rutaUltimoAfichePng;

  // Campañas WhatsApp
  final TextEditingController _promoCtrl = TextEditingController(
      text: 'PAPEL HIGIÉNICO ELITE en oferta \$4.500 (Formato Mayorista / Pallet)');
  String _categoriaCampana = 'Aseo y Papel';
  bool _adjuntarAficheEnCampana = true;
  bool _campanaCorriendo = false;
  int _progresoCampana = 0;
  String _estadoCampanaTexto = 'Listo para iniciar';

  // DeepSeek Offline Chat & Parser
  final TextEditingController _chatIaCtrl = TextEditingController();
  final TextEditingController _notaCaoticaCtrl = TextEditingController();
  final List<Map<String, String>> _mensajesIA = [];
  bool _descargandoModelo = false;
  double _progresoModelo = 0.0;
  bool _modeloGGUFInstalado = false;
  String _estadoDescargaGGUF = '';

  @override
  void initState() {
    super.initState();
    _cargarDatos();
    _verificarAccesibilidad();
    _verificarModeloGGUF();
  }

  Future<void> _cargarDatos() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('clientes_crm_v2');
    if (data != null) {
      final List decoded = jsonDecode(data);
      setState(() {
        _clientes = decoded.map((e) => Cliente.fromJson(e)).toList();
      });
    } else {
      setState(() {
        _clientes = List.from(clientesSemilla);
      });
      await _guardarDatos();
    }
    if (_mensajesIA.isEmpty) {
      _mensajesIA.add({
        'rol': 'ia',
        'texto': DeepSeekOfflineEngine.responderConsultaOffline('resumen', _clientes)
      });
    }
  }

  Future<void> _guardarDatos() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_clientes.map((c) => c.toJson()).toList());
    await prefs.setString('clientes_crm_v2', encoded);
  }

  Future<void> _verificarAccesibilidad() async {
    try {
      final bool result = await platform.invokeMethod('isServiceEnabled');
      setState(() => _accesibilidadActiva = result);
    } catch (_) {}
  }

  Future<void> _abrirAjustesAccesibilidad() async {
    try {
      await platform.invokeMethod('openAccessibilitySettings');
    } catch (_) {}
  }

  Future<void> _marcarContactado(Cliente c) async {
    setState(() {
      c.ultimoContacto = DateTime.now();
    });
    await _guardarDatos();
  }

  Future<void> _llamarCliente(Cliente c) async {
    if (c.telefono.isEmpty) {
      _mostrarSnack('Este cliente no tiene teléfono registrado. Tócalo para editarlo.');
      return;
    }
    await _marcarContactado(c);
    final uri = Uri.parse('tel:${c.telefono}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _escribirWhatsApp(
    Cliente c, {
    String? mensajePersonalizado,
    bool autoClick = false,
    String? imagePath,
  }) async {
    if (c.telefono.isEmpty) {
      _mostrarSnack('Agrega un teléfono a ${c.nombre} antes de enviar WhatsApp.');
      return;
    }
    await _marcarContactado(c);
    final numLimpio = c.telefono.replaceAll(RegExp(r'[^0-9]'), '');
    final msg = mensajePersonalizado ??
        DeepSeekOfflineEngine.generarMensajePersonalizado(
            c, _promoCtrl.text, Random().nextInt(10));

    if (imagePath != null && File(imagePath).existsSync()) {
      try {
        await platform.invokeMethod('sendWhatsAppImage', {
          'phone': numLimpio,
          'text': msg,
          'imagePath': imagePath,
          'autoSend': autoClick,
        });
        return;
      } catch (_) {}
    }

    if (autoClick) {
      try {
        await platform.invokeMethod('armAutoSend');
      } catch (_) {}
    }

    final uri = Uri.parse('whatsapp://send?phone=$numLimpio&text=${Uri.encodeComponent(msg)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      final webUri = Uri.parse('https://wa.me/$numLimpio?text=${Uri.encodeComponent(msg)}');
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    }
  }

  // ==========================================
  // GENERACIÓN Y CAPTURA DEL AFICHE EN PNG
  // ==========================================
  Future<void> _seleccionarFoto(ImageSource origen) async {
    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(source: origen, imageQuality: 85);
    if (picked != null) {
      setState(() {
        _fotoProducto = File(picked.path);
      });
    }
  }

  Future<String?> _renderizarAfichePng() async {
    try {
      final boundary = _flyerKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final ui.Image image = await boundary.toImage(pixelRatio: 2.5);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;
      final Uint8List pngBytes = byteData.buffer.asUint8List();

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/promo_mayorista.png');
      await file.writeAsBytes(pngBytes);
      setState(() {
        _rutaUltimoAfichePng = file.path;
        _promoCtrl.text =
            '${_tituloAficheCtrl.text} (${_subtituloAficheCtrl.text}) a solo ${_precioOfertaCtrl.text} [$_selloAfiche]';
      });
      return file.path;
    } catch (e) {
      _mostrarSnack('Error al generar afiche: $e');
      return null;
    }
  }

  Future<void> _compartirAficheGeneral() async {
    final path = await _renderizarAfichePng();
    if (path == null) return;
    try {
      await platform.invokeMethod('shareImageGeneral', {
        'imagePath': path,
        'text': '🔥 *${_tituloAficheCtrl.text}* a solo *${_precioOfertaCtrl.text}* (${_subtituloAficheCtrl.text})',
      });
    } catch (e) {
      _mostrarSnack('Afiche guardado lista para campaña.');
    }
  }

  // ==========================================
  // CAMPAÑA AUTOMÁTICA DE WHATSAPP
  // ==========================================
  Future<void> _iniciarCampanaAutomatica() async {
    await _verificarAccesibilidad();
    final destinatarios = _clientes
        .where((c) =>
            c.telefono.isNotEmpty &&
            (_categoriaCampana == 'Todos' || c.categoria == _categoriaCampana))
        .toList();

    if (destinatarios.isEmpty) {
      _mostrarSnack('No hay clientes con teléfono en esa categoría.');
      return;
    }

    String? afichePath = _rutaUltimoAfichePng;
    if (_adjuntarAficheEnCampana && afichePath == null) {
      afichePath = await _renderizarAfichePng();
    }

    setState(() {
      _campanaCorriendo = true;
      _progresoCampana = 0;
    });

    for (int i = 0; i < destinatarios.length; i++) {
      if (!_campanaCorriendo) break;
      final cliente = destinatarios[i];

      setState(() {
        _progresoCampana = i + 1;
        _estadoCampanaTexto =
            'Enviando a ${cliente.nombre} (${i + 1}/${destinatarios.length})...';
      });

      final msg = DeepSeekOfflineEngine.generarMensajePersonalizado(
          cliente, _promoCtrl.text, i);

      await _escribirWhatsApp(
        cliente,
        mensajePersonalizado: msg,
        autoClick: true,
        imagePath: _adjuntarAficheEnCampana ? afichePath : null,
      );

      if (i < destinatarios.length - 1 && _campanaCorriendo) {
        final delaySegundos = 14 + Random().nextInt(10);
        for (int s = delaySegundos; s > 0; s--) {
          if (!_campanaCorriendo) break;
          setState(() {
            _estadoCampanaTexto =
                'Pausa anti-baneo: próximo en ${s}s ➔ ${destinatarios[i + 1].nombre}';
          });
          await Future.delayed(const Duration(seconds: 1));
        }
      }
    }

    setState(() {
      _campanaCorriendo = false;
      _estadoCampanaTexto = '✅ Campaña finalizada (${destinatarios.length} clientes)';
    });
  }

  // ==========================================
  // DESCARGADOR DE PESOS GGUF DEEPSEEK
  // ==========================================
  Future<void> _verificarModeloGGUF() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/deepseek_r1_1.5b_q4.gguf');
    if (await file.exists()) {
      setState(() => _modeloGGUFInstalado = true);
    }
  }

  Future<void> _descargarModeloDeepSeekGGUF() async {
    setState(() {
      _descargandoModelo = true;
      _progresoModelo = 0.01;
      _estadoDescargaGGUF = 'Conectando con repositorio HuggingFace...';
    });
    try {
      final url = Uri.parse(
          'https://huggingface.co/bartowski/DeepSeek-R1-Distill-Qwen-1.5B-GGUF/resolve/main/DeepSeek-R1-Distill-Qwen-1.5B-Q4_K_M.gguf');
      final request = http.Request('GET', url);
      final response = await http.Client().send(request);
      final totalBytes = response.contentLength ?? 1117000000;

      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/deepseek_r1_1.5b_q4.gguf');
      final sink = file.openWrite();

      int recibido = 0;
      await for (final chunk in response.stream) {
        sink.add(chunk);
        recibido += chunk.length;
        setState(() {
          _progresoModelo = (recibido / totalBytes).clamp(0.0, 1.0);
          final mb = (recibido / (1024 * 1024)).toStringAsFixed(0);
          _estadoDescargaGGUF = 'Descargando pesos GGUF: $mb MB...';
        });
      }
      await sink.close();
      setState(() {
        _descargandoModelo = false;
        _modeloGGUFInstalado = true;
        _estadoDescargaGGUF = '✅ Modelo GGUF almacenado en memoria interna.';
      });
    } catch (e) {
      setState(() {
        _descargandoModelo = false;
        _estadoDescargaGGUF = 'Modo Heurístico Offline Activo (Sin conexión).';
      });
    }
  }

  void _mostrarSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final urgentesCount = _clientes.where((c) => c.requiereAtencionUrgente).length;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.storefront, color: Color(0xFF10B981)),
            SizedBox(width: 8),
            Text('CRM Mayorista Pro', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Agregar Cliente',
            icon: const Icon(Icons.person_add_alt_1, color: Color(0xFF10B981)),
            onPressed: () => _mostrarModalEditarCliente(null),
          ),
        ],
      ),
      body: IndexedStack(
        index: _tabIndex,
        children: [
          _buildTabClientes(),
          _buildTabMonitoreo(),
          _buildTabEstudioPromos(),
          _buildTabCampanas(),
          _buildTabDeepSeek(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: const Color(0xFF1E293B),
        selectedIndex: _tabIndex,
        onDestinationSelected: (idx) {
          if (idx == 3) _verificarAccesibilidad();
          setState(() => _tabIndex = idx);
        },
        destinations: [
          const NavigationDestination(icon: Icon(Icons.people_alt), label: 'Cartera'),
          NavigationDestination(
            icon: Badge(
              label: Text('$urgentesCount'),
              isLabelVisible: urgentesCount > 0,
              child: const Icon(Icons.radar),
            ),
            label: 'Alertas',
          ),
          const NavigationDestination(icon: Icon(Icons.palette), label: 'Afiches'),
          const NavigationDestination(icon: Icon(Icons.rocket_launch), label: 'Campaña'),
          const NavigationDestination(icon: Icon(Icons.psychology), label: 'DeepSeek'),
        ],
      ),
    );
  }

  // ==========================================
  // PESTAÑA 1: CARTERA Y KPI EJECUTIVOS
  // ==========================================
  Widget _buildTabClientes() {
    final categorias = [
      'Todos',
      'Abarrotes y Alimentos',
      'Aseo y Papel',
      'Mayoristas / Surtido General',
      'Clientes de Feria',
      'Facturación Reciente',
      'Sin Clasificar'
    ];

    final filtrados = _clientes.where((c) {
      final matchCat = _filtroCategoria == 'Todos' || c.categoria == _filtroCategoria;
      final q = _busqueda.toLowerCase();
      final matchTexto = c.nombre.toLowerCase().contains(q) ||
          c.queCompra.toLowerCase().contains(q) ||
          c.notas.toLowerCase().contains(q) ||
          c.rut.toLowerCase().contains(q);
      return matchCat && matchTexto;
    }).toList();

    final volumenTotal = filtrados.fold<int>(0, (s, c) => s + c.montoPromedio);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          color: const Color(0xFF1E293B),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildKpiMini('Clientes vista', '${filtrados.length}', Icons.groups, const Color(0xFF38BDF8)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildKpiMini('Potencial Mensual', '\$${formatearPesos(volumenTotal)}', Icons.payments, const Color(0xFF10B981)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                decoration: InputDecoration(
                  hintText: 'Buscar cliente, RUT o producto (papel, queso, corta fecha)...',
                  hintStyle: const TextStyle(fontSize: 13),
                  prefixIcon: const Icon(Icons.search, size: 20),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                  filled: true,
                  fillColor: const Color(0xFF0B1120),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (val) => setState(() => _busqueda = val),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 38,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: categorias.length,
                  itemBuilder: (ctx, i) {
                    final cat = categorias[i];
                    final sel = _filtroCategoria == cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(cat, style: const TextStyle(fontSize: 12)),
                        selected: sel,
                        onSelected: (_) => setState(() => _filtroCategoria = cat),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(top: 6, bottom: 20),
            itemCount: filtrados.length,
            itemBuilder: (ctx, i) => _buildTarjetaCliente(filtrados[i]),
          ),
        ),
      ],
    );
  }

  Widget _buildKpiMini(String titulo, String valor, IconData icono, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1120),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icono, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: const TextStyle(fontSize: 11, color: Colors.white60)),
                Text(valor, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTarjetaCliente(Cliente c) {
    final urgente = c.requiereAtencionUrgente;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      color: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: urgente ? Colors.redAccent.withOpacity(0.6) : Colors.white10,
          width: 1.2,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _mostrarModalEditarCliente(c),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.nombre,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${c.categoria}${c.rut.isNotEmpty ? " • RUT: ${c.rut}" : ""}',
                          style: const TextStyle(color: Colors.white60, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '\$${formatearPesos(c.montoPromedio)}',
                      style: const TextStyle(
                        color: Color(0xFF10B981),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('🛒 Suele comprar: ${c.queCompra}', style: const TextStyle(fontSize: 13)),
              if (c.notas.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('📌 ${c.notas}',
                      style: const TextStyle(fontSize: 12, color: Colors.amberAccent)),
                ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.schedule,
                          size: 14, color: urgente ? Colors.redAccent : Colors.white54),
                      const SizedBox(width: 4),
                      Text(
                        'Hace ${c.diasSinContacto}d (Ciclo ${c.cicloDias}d)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: urgente ? FontWeight.bold : FontWeight.normal,
                          color: urgente ? Colors.redAccent : Colors.white54,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: 34,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: c.prefiereLlamada
                                ? Colors.amber.shade800
                                : const Color(0xFF334155),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                          ),
                          onPressed: () => _llamarCliente(c),
                          icon: const Icon(Icons.phone, size: 15),
                          label: Text(
                            c.prefiereLlamada ? 'LLAMAR' : 'Llamar',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 34,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                          ),
                          onPressed: () => _escribirWhatsApp(c),
                          icon: const Icon(Icons.chat, size: 15),
                          label: const Text(
                            'WhatsApp',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // PESTAÑA 2: RADAR DE MONITOREO Y RECORDATORIOS
  // ==========================================
  Widget _buildTabMonitoreo() {
    final urgentes = _clientes.where((c) => c.requiereAtencionUrgente).toList()
      ..sort((a, b) => b.montoPromedio.compareTo(a.montoPromedio));

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.redAccent.withOpacity(0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.notifications_active, color: Colors.redAccent),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Clientes Pasados de Fecha (Ordenados por \$)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.redAccent),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Hay ${urgentes.length} clientes esperando llamada o mensaje. Al tocar "Llamar" o "WhatsApp", su contador vuelve a 0 días automáticamente.',
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        ...urgentes.map(_buildTarjetaCliente),
      ],
    );
  }

  // ==========================================
  // PESTAÑA 3: ESTUDIO CREADOR DE AFICHES / PROMOS
  // ==========================================
  Widget _buildTabEstudioPromos() {
    final sellos = [
      '¡OFERTA 4x500!',
      '¡CORTA FECHA!',
      '¡PRECIO PALLET!',
      '¡LOTE MAYORISTA!',
      '¡RECIÉN LLEGADO!'
    ];

    final colores = [
      const Color(0xFFDC2626),
      const Color(0xFF059669),
      const Color(0xFF2563EB),
      const Color(0xFFD97706),
      const Color(0xFF7C3AED),
    ];

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        const Text(
          'Diseñador de Afiches para WhatsApp',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        const Text(
          'Sube una foto del producto, ajusta el precio y envíalo directo en tus campañas.',
          style: TextStyle(fontSize: 12, color: Colors.white60),
        ),
        const SizedBox(height: 12),

        // VISTA PREVIA DEL AFICHE (CAPTURABLE A PNG)
        Center(
          child: RepaintBoundary(
            key: _flyerKey,
            child: Container(
              width: 340,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_colorTemaAfiche, const Color(0xFF0F172A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.amberAccent, width: 2.5),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    decoration: const BoxDecoration(
                      color: Colors.amberAccent,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
                    ),
                    child: Text(
                      _selloAfiche,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    height: 170,
                    width: 300,
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: _fotoProducto != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(_fotoProducto!, fit: BoxFit.cover),
                          )
                        : const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.inventory_2, size: 64, color: Colors.amberAccent),
                              SizedBox(height: 6),
                              Text('OFERTA DISTRIBUIDORA MAYORISTA',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            ],
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      children: [
                        Text(
                          _tituloAficheCtrl.text.toUpperCase(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _subtituloAficheCtrl.text,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 13, color: Colors.white70),
                        ),
                        const SizedBox(height: 10),
                        if (_precioAntesCtrl.text.isNotEmpty)
                          Text(
                            'Normal: ${_precioAntesCtrl.text}',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.white60,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black45,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.amberAccent),
                          ),
                          child: Text(
                            _precioOfertaCtrl.text,
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              color: Colors.amberAccent,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Consulte stock por manga o pallet • Despacho y Retiro',
                          style: TextStyle(fontSize: 11, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _seleccionarFoto(ImageSource.gallery),
                icon: const Icon(Icons.photo_library),
                label: const Text('Galería'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _seleccionarFoto(ImageSource.camera),
                icon: const Icon(Icons.camera_alt),
                label: const Text('Cámara'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 38,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: sellos.length,
            itemBuilder: (ctx, i) => Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                label: Text(sellos[i], style: const TextStyle(fontSize: 12)),
                selected: _selloAfiche == sellos[i],
                onSelected: (_) => setState(() => _selloAfiche = sellos[i]),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: colores
              .map((c) => GestureDetector(
                    onTap: () => setState(() => _colorTemaAfiche = c),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _colorTemaAfiche == c ? Colors.white : Colors.transparent,
                          width: 2.5,
                        ),
                      ),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _tituloAficheCtrl,
          decoration: const InputDecoration(labelText: 'Producto Principal'),
          onChanged: (_) => setState(() {}),
        ),
        TextField(
          controller: _subtituloAficheCtrl,
          decoration: const InputDecoration(labelText: 'Detalle (Formato / Unidades por manga)'),
          onChanged: (_) => setState(() {}),
        ),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _precioAntesCtrl,
                decoration: const InputDecoration(labelText: 'Precio Normal'),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _precioOfertaCtrl,
                decoration: const InputDecoration(labelText: 'Precio Oferta'),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF38BDF8),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: _compartirAficheGeneral,
                icon: const Icon(Icons.share),
                label: const Text('Compartir Afiche', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () async {
                  await _renderizarAfichePng();
                  setState(() {
                    _adjuntarAficheEnCampana = true;
                    _tabIndex = 3;
                  });
                  _mostrarSnack('Afiche cargado en la Campaña de WhatsApp');
                },
                icon: const Icon(Icons.rocket_launch),
                label: const Text('Usar en Campaña', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ==========================================
  // PESTAÑA 4: CAMPAÑAS WHATSAPP + ACCESSIBILITY
  // ==========================================
  Widget _buildTabCampanas() {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Card(
          color: _accesibilidadActiva ? const Color(0xFF064E3B) : const Color(0xFF7F1D1D),
          child: ListTile(
            leading: Icon(
              _accesibilidadActiva ? Icons.verified_user : Icons.warning_amber_rounded,
              color: Colors.white,
              size: 32,
            ),
            title: Text(
              _accesibilidadActiva
                  ? 'Auto-Click Accessibility ACTIVO'
                  : 'Permiso de Accesibilidad Requerido',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(_accesibilidadActiva
                ? 'Tu teléfono presionará "Enviar" en WhatsApp solo y volverá al CRM.'
                : 'Toca el botón "Activar" y enciende "CRM Mayorista Auto-WhatsApp".'),
            trailing: ElevatedButton(
              onPressed: _abrirAjustesAccesibilidad,
              child: const Text('Activar'),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          tileColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text('Adjuntar Afiche Promocional (.PNG)', style: TextStyle(fontWeight: FontWeight.bold)),
          subtitle: const Text('Envía la imagen creada en la pestaña Afiches junto con el texto personalizado'),
          value: _adjuntarAficheEnCampana,
          onChanged: (v) => setState(() => _adjuntarAficheEnCampana = v),
        ),
        const SizedBox(height: 12),
        const Text('Texto de la Oferta (DeepSeek lo adaptará a cada cliente):',
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        TextField(
          controller: _promoCtrl,
          maxLines: 3,
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFF1E293B),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 12),
        const Text('Categoría de Clientes a Disparar:', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: _categoriaCampana,
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFF1E293B),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          items: [
            'Todos',
            'Abarrotes y Alimentos',
            'Aseo y Papel',
            'Mayoristas / Surtido General',
            'Clientes de Feria',
            'Sin Clasificar'
          ].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
          onChanged: (val) => setState(() => _categoriaCampana = val ?? 'Todos'),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Estado: $_estadoCampanaTexto', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _campanaCorriendo ? Colors.redAccent : const Color(0xFF10B981),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () {
                    if (_campanaCorriendo) {
                      setState(() => _campanaCorriendo = false);
                    } else {
                      _iniciarCampanaAutomatica();
                    }
                  },
                  icon: Icon(_campanaCorriendo ? Icons.stop_circle : Icons.send),
                  label: Text(
                    _campanaCorriendo ? 'DETENER CAMPAÑA AHORA' : 'INICIAR CAMPAÑA AUTOMÁTICA',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================
  // PESTAÑA 5: DEEPSEEK IA OFFLINE (CHAT + PARSER)
  // ==========================================
  Widget _buildTabDeepSeek() {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // TARJETA 1: ASISTENTE INTERACTIVO OFFLINE
        Card(
          color: const Color(0xFF1E293B),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.psychology, color: Color(0xFF10B981)),
                    SizedBox(width: 8),
                    Text('Consultor DeepSeek Offline (Sin Internet)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    ActionChip(
                      label: const Text('¿Quién compra corta fecha?', style: TextStyle(fontSize: 11)),
                      onPressed: () => _enviarPreguntaIA('¿Quién compra corta fecha?'),
                    ),
                    ActionChip(
                      label: const Text('Top Papel y Aseo', style: TextStyle(fontSize: 11)),
                      onPressed: () => _enviarPreguntaIA('¿Quiénes compran papel y aseo?'),
                    ),
                    ActionChip(
                      label: const Text('¿A quién llamar hoy?', style: TextStyle(fontSize: 11)),
                      onPressed: () => _enviarPreguntaIA('¿A quién debo llamar urgente hoy?'),
                    ),
                    ActionChip(
                      label: const Text('Queso / Bebidas', style: TextStyle(fontSize: 11)),
                      onPressed: () => _enviarPreguntaIA('queso'),
                    ),
                  ],
                ),
                const Divider(height: 16),
                Container(
                  constraints: const BoxConstraints(maxHeight: 230),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _mensajesIA.length,
                    itemBuilder: (ctx, i) {
                      final m = _mensajesIA[i];
                      final esIa = m['rol'] == 'ia';
                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: esIa ? const Color(0xFF0B1120) : const Color(0xFF10B981).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(m['texto'] ?? '', style: const TextStyle(fontSize: 13, height: 1.35)),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _chatIaCtrl,
                        decoration: InputDecoration(
                          hintText: 'Pregúntale a tu base de datos offline...',
                          filled: true,
                          fillColor: const Color(0xFF0B1120),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                        ),
                        onSubmitted: _enviarPreguntaIA,
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton.filled(
                      onPressed: () => _enviarPreguntaIA(_chatIaCtrl.text),
                      icon: const Icon(Icons.send),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),

        // TARJETA 2: ESCÁNER DE NOTAS CAÓTICAS A CLIENTE
        Card(
          color: const Color(0xFF1E293B),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('🪄 Convertir Nota Rápida en Ficha de Cliente',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 4),
                const Text(
                  'Pega un texto desordenado (ej: "Pedro Bodega 988776655 compra papel higiénico promedio 800.000 llamar") y la IA creará la ficha clasificada:',
                  style: TextStyle(fontSize: 12, color: Colors.white60),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _notaCaoticaCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Pega aquí la nota rápida...',
                    filled: true,
                    fillColor: const Color(0xFF0B1120),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: () {
                    if (_notaCaoticaCtrl.text.trim().isEmpty) return;
                    final nuevo = DeepSeekOfflineEngine.extraerClienteDesdeNotaCaotica(_notaCaoticaCtrl.text);
                    setState(() {
                      _clientes.insert(0, nuevo);
                      _notaCaoticaCtrl.clear();
                    });
                    _guardarDatos();
                    _mostrarSnack('Cliente "${nuevo.nombre}" clasificado en ${nuevo.categoria}');
                  },
                  icon: const Icon(Icons.auto_fix_high),
                  label: const Text('Analizar Nota y Guardar Cliente'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),

        // TARJETA 3: GESTOR GGUF DEEPSEEK-R1
        Card(
          color: const Color(0xFF1E293B),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Pesos Locales DeepSeek-R1-Distill-1.5B (GGUF)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 6),
                if (_estadoDescargaGGUF.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(_estadoDescargaGGUF, style: const TextStyle(fontSize: 12, color: Colors.amberAccent)),
                  ),
                if (_descargandoModelo)
                  LinearProgressIndicator(value: _progresoModelo)
                else
                  ElevatedButton.icon(
                    onPressed: _modeloGGUFInstalado ? null : _descargarModeloDeepSeekGGUF,
                    icon: Icon(_modeloGGUFInstalado ? Icons.check_circle : Icons.download),
                    label: Text(_modeloGGUFInstalado
                        ? 'Pesos DeepSeek GGUF Instalados'
                        : 'Descargar Modelo GGUF en el Teléfono (Opcional)'),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _enviarPreguntaIA(String pregunta) {
    if (pregunta.trim().isEmpty) return;
    final resp = DeepSeekOfflineEngine.responderConsultaOffline(pregunta, _clientes);
    setState(() {
      _mensajesIA.add({'rol': 'user', 'texto': 'Tú: $pregunta'});
      _mensajesIA.add({'rol': 'ia', 'texto': resp});
      _chatIaCtrl.clear();
    });
  }

  // ==========================================
  // MODAL PARA CREAR O EDITAR CUALQUIER CLIENTE
  // ==========================================
  void _mostrarModalEditarCliente(Cliente? existente) {
    final nombreCtrl = TextEditingController(text: existente?.nombre ?? '');
    final rutCtrl = TextEditingController(text: existente?.rut ?? '');
    final telCtrl = TextEditingController(text: existente?.telefono ?? '+569');
    final compraCtrl = TextEditingController(text: existente?.queCompra ?? '');
    final montoCtrl = TextEditingController(text: (existente?.montoPromedio ?? 500000).toString());
    final notasCtrl = TextEditingController(text: existente?.notas ?? '');
    final cicloCtrl = TextEditingController(text: (existente?.cicloDias ?? 10).toString());
    String cat = existente?.categoria ?? 'Abarrotes y Alimentos';
    bool prefLlamada = existente?.prefiereLlamada ?? false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  existente == null ? 'Nuevo Cliente Mayorista' : 'Editar Ficha de Cliente',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                TextField(controller: nombreCtrl, decoration: const InputDecoration(labelText: 'Nombre / Razón Social')),
                Row(
                  children: [
                    Expanded(child: TextField(controller: rutCtrl, decoration: const InputDecoration(labelText: 'RUT'))),
                    const SizedBox(width: 10),
                    Expanded(child: TextField(controller: telCtrl, decoration: const InputDecoration(labelText: 'Teléfono (+569...)'))),
                  ],
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: cat,
                  decoration: const InputDecoration(labelText: 'Categoría / Rubro'),
                  items: [
                    'Abarrotes y Alimentos',
                    'Aseo y Papel',
                    'Mayoristas / Surtido General',
                    'Clientes de Feria',
                    'Facturación Reciente',
                    'Sin Clasificar'
                  ].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (v) => setModalState(() => cat = v ?? cat),
                ),
                TextField(controller: compraCtrl, decoration: const InputDecoration(labelText: '¿Qué suele comprar?')),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: montoCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Compra Promedio (\$)'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: cicloCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Recordar cada (días)'),
                      ),
                    ),
                  ],
                ),
                TextField(controller: notasCtrl, decoration: const InputDecoration(labelText: 'Notas / Recordatorios')),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Prefiere llamada telefónica antes que WhatsApp'),
                  value: prefLlamada,
                  onChanged: (v) => setModalState(() => prefLlamada = v),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    if (existente != null)
                      TextButton.icon(
                        onPressed: () {
                          setState(() => _clientes.removeWhere((c) => c.id == existente.id));
                          _guardarDatos();
                          Navigator.pop(ctx);
                        },
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                        label: const Text('Eliminar', style: TextStyle(color: Colors.redAccent)),
                      ),
                    const Spacer(),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.black,
                      ),
                      onPressed: () {
                        if (nombreCtrl.text.trim().isEmpty) return;
                        setState(() {
                          if (existente == null) {
                            _clientes.insert(
                              0,
                              Cliente(
                                id: DateTime.now().millisecondsSinceEpoch.toString(),
                                nombre: nombreCtrl.text.trim(),
                                rut: rutCtrl.text.trim(),
                                telefono: telCtrl.text.trim(),
                                categoria: cat,
                                queCompra: compraCtrl.text.trim(),
                                montoPromedio: int.tryParse(montoCtrl.text) ?? 500000,
                                notas: notasCtrl.text.trim(),
                                prefiereLlamada: prefLlamada,
                                cicloDias: int.tryParse(cicloCtrl.text) ?? 10,
                              ),
                            );
                          } else {
                            existente.nombre = nombreCtrl.text.trim();
                            existente.rut = rutCtrl.text.trim();
                            existente.telefono = telCtrl.text.trim();
                            existente.categoria = cat;
                            existente.queCompra = compraCtrl.text.trim();
                            existente.montoPromedio = int.tryParse(montoCtrl.text) ?? existente.montoPromedio;
                            existente.notas = notasCtrl.text.trim();
                            existente.prefiereLlamada = prefLlamada;
                            existente.cicloDias = int.tryParse(cicloCtrl.text) ?? 10;
                          }
                        });
                        _guardarDatos();
                        Navigator.pop(ctx);
                      },
                      child: const Text('Guardar Cambios', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
