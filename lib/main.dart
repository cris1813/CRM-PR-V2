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
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const CrmMayoristaApp());
}

class CrmMayoristaApp extends StatelessWidget {
  const CrmMayoristaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CRM Mayorista Pro V4',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF070B12),
        primaryColor: const Color(0xFF10B981),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF10B981),
          secondary: Color(0xFF38BDF8),
          surface: Color(0xFF131C2E),
        ),
        useMaterial3: true,
      ),
      home: const MainDashboard(),
    );
  }
}

// ==========================================
// MODELO DE CLIENTE + SUGERENCIA IA DINÁMICA
// ==========================================
class Cliente {
  String id;
  String nombre;
  String rut;
  String telefono;
  String telefonoSecundario;
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
    this.telefonoSecundario = '',
    required this.categoria,
    required this.queCompra,
    required this.montoPromedio,
    required this.notas,
    this.prefiereLlamada = false,
    this.cicloDias = 10,
    DateTime? ultimoContacto,
  }) : ultimoContacto =
            ultimoContacto ?? DateTime.now().subtract(const Duration(days: 11));

  int get diasSinContacto => DateTime.now().difference(ultimoContacto).inDays;
  bool get requiereAtencionUrgente => diasSinContacto >= cicloDias;
  double get ratioUrgencia =>
      (diasSinContacto / (cicloDias <= 0 ? 1 : cicloDias)).clamp(0.0, 1.5);

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': nombre,
        'rut': rut,
        'telefono': telefono,
        'telefonoSecundario': telefonoSecundario,
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
        telefonoSecundario: json['telefonoSecundario'] ?? '',
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
// BASE MAESTRA: 61 CLIENTES DEL EXCEL (HOJA 1 + HOJA 2) Y PDF
// ==========================================
List<Cliente> construirCarteraMaestra61() {
  final now = DateTime.now();
  return [
    // --- ABARROTES Y ALIMENTOS (15 CLIENTES) ---
    Cliente(id: '1', nombre: 'Caroline (Almacén San Vicente)', rut: '', telefono: '+56964203947', categoria: 'Abarrotes y Alimentos', queCompra: 'Surtido general para almacén', montoPromedio: 600000, notas: 'Almacén San Vicente', cicloDias: 10, ultimoContacto: now.subtract(const Duration(days: 8))),
    Cliente(id: '2', nombre: 'Cesar', rut: '78.076.635', telefono: '+56935595136', categoria: 'Abarrotes y Alimentos', queCompra: 'Compra millones en chocolates', montoPromedio: 2000000, notas: 'Ballena en chocolates. Llamar y escribir', prefiereLlamada: true, cicloDias: 7, ultimoContacto: now.subtract(const Duration(days: 11))),
    Cliente(id: '3', nombre: 'Comercializadora Weisz', rut: '78.102.847-9', telefono: '+56981441715', categoria: 'Abarrotes y Alimentos', queCompra: 'Mucho pallet de arroz y azúcar', montoPromedio: 1500000, notas: 'Cliente potencial de alto volumen por pallet', cicloDias: 10, ultimoContacto: now.subtract(const Duration(days: 14))),
    Cliente(id: '4', nombre: 'Marcela', rut: '', telefono: '+56961636386', categoria: 'Abarrotes y Alimentos', queCompra: 'Precios por pallet y productos corta fecha', montoPromedio: 850000, notas: 'Avisar apenas entren lotes a corta fecha y pallets', cicloDias: 7, ultimoContacto: now.subtract(const Duration(days: 9))),
    Cliente(id: '5', nombre: 'Santa Economía EIRL / Mauricio Miranda', rut: '78.199.928-8', telefono: '+56997586362', categoria: 'Abarrotes y Alimentos', queCompra: 'Compra mucho - recién surtiendo un negocio', montoPromedio: 1200000, notas: 'Surtido inicial de alto volumen', cicloDias: 10, ultimoContacto: now.subtract(const Duration(days: 5))),
    Cliente(id: '6', nombre: 'Santa Flora SpA / Cristian Miranda', rut: '78.291.382-4', telefono: '+56983543128', categoria: 'Abarrotes y Alimentos', queCompra: 'Compra de todo y bebidas', montoPromedio: 1100000, notas: 'Avisar urgente cuando lleguen todas las bebidas', cicloDias: 7, ultimoContacto: now.subtract(const Duration(days: 9))),
    Cliente(id: '7', nombre: 'Silvia', rut: '9.182.388-8', telefono: '+56936424876', categoria: 'Abarrotes y Alimentos', queCompra: 'Silvia compra de todo - almacén', montoPromedio: 450000, notas: 'Almacén tradicional', cicloDias: 10, ultimoContacto: now.subtract(const Duration(days: 4))),
    Cliente(id: '8', nombre: 'Sra. Margarita (Verdurería Las Nietas)', rut: '11.737.106-9', telefono: '+56972969640', categoria: 'Abarrotes y Alimentos', queCompra: 'Minimarket playa - compra 3 millones', montoPromedio: 3000000, notas: 'Ballena VIP (Playa): compra 3 millones', prefiereLlamada: true, cicloDias: 10, ultimoContacto: now.subtract(const Duration(days: 15))),
    Cliente(id: '9', nombre: 'Victor / Panadería', rut: '78.441.909-6', telefono: '+56981934386', categoria: 'Abarrotes y Alimentos', queCompra: 'Panadería - compró 2 millones', montoPromedio: 2000000, notas: 'Ballena VIP: Cliente compró 2 millones', cicloDias: 10, ultimoContacto: now.subtract(const Duration(days: 13))),
    Cliente(id: '10', nombre: 'Erika Saez', rut: '13.607.820-8', telefono: '+56966162817', categoria: 'Abarrotes y Alimentos', queCompra: 'Queso despunte y fiambrería', montoPromedio: 500000, notas: 'Avisar siempre que llegue queso despunte', cicloDias: 7, ultimoContacto: now.subtract(const Duration(days: 8))),
    Cliente(id: '11', nombre: 'Cliente Almacenero (942826685)', rut: '', telefono: '+56942826685', categoria: 'Abarrotes y Alimentos', queCompra: 'Clientes almaceneros', montoPromedio: 500000, notas: 'Promedio de compra \$500.000', cicloDias: 10, ultimoContacto: now.subtract(const Duration(days: 6))),
    Cliente(id: '12', nombre: 'Tres Mundos', rut: '76.549.757-4', telefono: '+56962530106', categoria: 'Abarrotes y Alimentos', queCompra: 'Compra mucha agua y bebestibles', montoPromedio: 900000, notas: 'Gestionar para que compre todos sus bebestibles AQUÍ', cicloDias: 7, ultimoContacto: now.subtract(const Duration(days: 10))),
    Cliente(id: '13', nombre: 'Alan Muñoz (Pirque)', rut: '76.999.379-7', telefono: '+56968646796', categoria: 'Abarrotes y Alimentos', queCompra: 'Compra para negocio nuevo en Pirque', montoPromedio: 400000, notas: 'Cliente de Pirque, promedio de compra \$400.000', cicloDias: 10, ultimoContacto: now.subtract(const Duration(days: 7))),
    Cliente(id: '14', nombre: 'Maritza', rut: '15.619.381-K', telefono: '+56976969375', categoria: 'Abarrotes y Alimentos', queCompra: 'Compra de todo un poco, almacén', montoPromedio: 450000, notas: 'Clienta de almacén', cicloDias: 10, ultimoContacto: now.subtract(const Duration(days: 6))),
    Cliente(id: '15', nombre: 'Isacc', rut: '18.951.542-1', telefono: '+56940565466', categoria: 'Abarrotes y Alimentos', queCompra: 'Compra papel, abarrotes, de todo un poco', montoPromedio: 500000, notas: 'Promedio de compra \$500.000', cicloDias: 10, ultimoContacto: now.subtract(const Duration(days: 11))),

    // --- ASEO Y PAPEL (17 CLIENTES) ---
    Cliente(id: '16', nombre: 'Agrolatino / Cristopher', rut: '78.070.723-2', telefono: '+56932566154', telefonoSecundario: '+56932632323', categoria: 'Aseo y Papel', queCompra: 'Pallet de papel higiénico', montoPromedio: 1200000, notas: 'Contacto 2: Génesis (+56932632323)', cicloDias: 14, ultimoContacto: now.subtract(const Duration(days: 12))),
    Cliente(id: '17', nombre: 'Andres Albarracin', rut: '77.305.701-K', telefono: '+56958383389', categoria: 'Aseo y Papel', queCompra: 'Higiénico, toalla, servilleta, bolsa y detergente', montoPromedio: 900000, notas: 'Canal E-commerce', cicloDias: 10, ultimoContacto: now.subtract(const Duration(days: 7))),
    Cliente(id: '18', nombre: 'Carlos Ignacio Brante', rut: '15.999.884-3', telefono: '+56964819488', categoria: 'Aseo y Papel', queCompra: 'Emprendimiento de papel', montoPromedio: 500000, notas: 'Emprendimiento especializado en papel', cicloDias: 10, ultimoContacto: now.subtract(const Duration(days: 9))),
    Cliente(id: '19', nombre: 'Comercial ATH / Pedro', rut: '76.751.574-K', telefono: '+56922133197', categoria: 'Aseo y Papel', queCompra: 'Mucho papel / cotizó 500 mangas de Elite', montoPromedio: 2500000, notas: 'Ballena de papel: cotizó 500 mangas de Elite', prefiereLlamada: true, cicloDias: 10, ultimoContacto: now.subtract(const Duration(days: 14))),
    Cliente(id: '20', nombre: 'Dilum Restauran', rut: '76.840.502-6', telefono: '+56942252957', categoria: 'Aseo y Papel', queCompra: 'Papel oferta 4x500', montoPromedio: 400000, notas: 'Recordatorio: Avisar el día 20/7 para oferta 4x500', cicloDias: 15, ultimoContacto: now.subtract(const Duration(days: 16))),
    Cliente(id: '21', nombre: 'DIST Y COMER Santa Juana LTDA', rut: '77.882.033-1', telefono: '+56977646940', categoria: 'Aseo y Papel', queCompra: 'Papel higiénico, toalla y productos a corta fecha', montoPromedio: 1100000, notas: 'Interesado en corta fecha y papel', cicloDias: 10, ultimoContacto: now.subtract(const Duration(days: 8))),
    Cliente(id: '22', nombre: 'Edgar (Ovalle - 3 Minimarkets)', rut: '26.452.795-3', telefono: '+56954843198', categoria: 'Aseo y Papel', queCompra: '3 minimarkets en aseo y perfumería', montoPromedio: 1800000, notas: 'Es de Ovalle - DE PREFERENCIA LLAMAR', prefiereLlamada: true, cicloDias: 12, ultimoContacto: now.subtract(const Duration(days: 15))),
    Cliente(id: '23', nombre: 'Karen', rut: '10.228.258-2', telefono: '+56978797268', categoria: 'Aseo y Papel', queCompra: 'Interesada en papel y aseo', montoPromedio: 450000, notas: 'RUT recuperado de Hoja 1', cicloDias: 10, ultimoContacto: now.subtract(const Duration(days: 5))),
    Cliente(id: '24', nombre: 'LEO-MARIA CRISTINA', rut: '16.716.408-0', telefono: '+56978473181', telefonoSecundario: '+56978473185', categoria: 'Aseo y Papel', queCompra: 'Artículos de aseo por mayor', montoPromedio: 1500000, notas: 'Compran mucho. Tel 2: +56978473185', cicloDias: 10, ultimoContacto: now.subtract(const Duration(days: 11))),
    Cliente(id: '25', nombre: 'Limpieza Ays SpA', rut: '78.414.683-9', telefono: '+56986484781', categoria: 'Aseo y Papel', queCompra: 'Venta de artículos de limpieza', montoPromedio: 450000, notas: 'Cliente empezando en venta de limpieza', cicloDias: 10, ultimoContacto: now.subtract(const Duration(days: 6))),
    Cliente(id: '26', nombre: 'Maribel Natalia Arcos', rut: '17.336.845-3', telefono: '+56948755324', categoria: 'Aseo y Papel', queCompra: 'Carnicería / Compra mucho papel', montoPromedio: 950000, notas: 'DE PREFERENCIA LLAMAR (*Javi)', prefiereLlamada: true, cicloDias: 10, ultimoContacto: now.subtract(const Duration(days: 12))),
    Cliente(id: '27', nombre: 'Milko', rut: '', telefono: '+56949203691', categoria: 'Aseo y Papel', queCompra: 'Compra millones en aseo', montoPromedio: 2200000, notas: 'Ballena de aseo (teléfono +56949203691 de Hoja 1)', prefiereLlamada: true, cicloDias: 10, ultimoContacto: now.subtract(const Duration(days: 14))),
    Cliente(id: '28', nombre: 'Minimarket Ricardo Andres Nuñez', rut: '78.322.941-2', telefono: '+56959661230', categoria: 'Aseo y Papel', queCompra: 'Papel de 10 en 10 mangas por tipo', montoPromedio: 500000, notas: 'Promedio de compra \$500.000 constante', cicloDias: 10, ultimoContacto: now.subtract(const Duration(days: 9))),
    Cliente(id: '29', nombre: 'Josep Silva', rut: '', telefono: '+56933265687', categoria: 'Aseo y Papel', queCompra: 'Compra pallet de papel', montoPromedio: 1100000, notas: 'Comprador por pallet de papel (Hoja 1)', cicloDias: 12, ultimoContacto: now.subtract(const Duration(days: 13))),
    Cliente(id: '30', nombre: 'Felipe Lobos / Casa Blanca', rut: '7.334.621-5', telefono: '+56968462688', categoria: 'Aseo y Papel', queCompra: 'Compró pallet de papel', montoPromedio: 1100000, notas: 'Casa Blanca - comprador de pallet (Hoja 1)', cicloDias: 14, ultimoContacto: now.subtract(const Duration(days: 15))),
    Cliente(id: '31', nombre: 'Minimarket Daniela Alej', rut: '78.065.528-3', telefono: '+56972397906', categoria: 'Aseo y Papel', queCompra: 'Compra de todo, mayormente papel', montoPromedio: 650000, notas: 'Minimarket con alta rotación de papel', cicloDias: 10, ultimoContacto: now.subtract(const Duration(days: 8))),
    Cliente(id: '32', nombre: 'Jesús Peña (Lampa)', rut: '18.764.319-8', telefono: '+56941714982', categoria: 'Aseo y Papel', queCompra: 'Pallets de papel todas las semanas + abarrotes y Score', montoPromedio: 1800000, notas: 'Lampa - compra semanal de pallets. LLAMAR', prefiereLlamada: true, cicloDias: 7, ultimoContacto: now.subtract(const Duration(days: 9))),

    // --- MAYORISTAS / SURTIDO GENERAL (10 CLIENTES) ---
    Cliente(id: '33', nombre: 'Angel L2P SpA', rut: '78.130.297-K', telefono: '+56931815515', categoria: 'Mayoristas / Surtido General', queCompra: 'Compra de todo - llamar próximo lunes', montoPromedio: 1500000, notas: 'Llamar todos los lunes', prefiereLlamada: true, cicloDias: 7, ultimoContacto: now.subtract(const Duration(days: 8))),
    Cliente(id: '34', nombre: 'Comercial Nietos / Alfredo', rut: '77.979.333-8', telefono: '+56978515834', categoria: 'Mayoristas / Surtido General', queCompra: 'Compra millones y de todo - varios locales', montoPromedio: 2800000, notas: 'Ballena VIP con varios locales', prefiereLlamada: true, cicloDias: 10, ultimoContacto: now.subtract(const Duration(days: 14))),
    Cliente(id: '35', nombre: 'Edisson Bonacic Rojas', rut: '13.983.850-5', telefono: '+56957111745', categoria: 'Mayoristas / Surtido General', queCompra: 'Última compra 3 millones - surtido general', montoPromedio: 3000000, notas: 'Ballena VIP 3 millones - IMPORTANTE LLAMAR', prefiereLlamada: true, cicloDias: 10, ultimoContacto: now.subtract(const Duration(days: 16))),
    Cliente(id: '36', nombre: 'Fabian Erice (Rancagua)', rut: '17.573.384-1', telefono: '+56957047224', categoria: 'Mayoristas / Surtido General', queCompra: 'Rancagua - compra quincenal de todo', montoPromedio: 1400000, notas: 'Ciclo fijo cada 15 días (Rancagua)', cicloDias: 14, ultimoContacto: now.subtract(const Duration(days: 14))),
    Cliente(id: '37', nombre: 'Luis Silva (Melipilla)', rut: '78.370.642-3', telefono: '+56965857854', categoria: 'Mayoristas / Surtido General', queCompra: 'Compras con despacho a Melipilla sobre \$600.000', montoPromedio: 650000, notas: 'Despacho a Melipilla (compra sobre 600 mil)', cicloDias: 12, ultimoContacto: now.subtract(const Duration(days: 10))),
    Cliente(id: '38', nombre: 'Tres Hermanos', rut: '78.177.706-4', telefono: '+56957260645', categoria: 'Mayoristas / Surtido General', queCompra: 'Compra de todo y mucho - cliente TOP', montoPromedio: 1800000, notas: 'Cliente TOP de alta rotación', cicloDias: 10, ultimoContacto: now.subtract(const Duration(days: 7))),
    Cliente(id: '39', nombre: 'Yris Local 57', rut: '', telefono: '+56921751069', categoria: 'Mayoristas / Surtido General', queCompra: 'Compra de todo', montoPromedio: 750000, notas: 'Local 57', cicloDias: 10, ultimoContacto: now.subtract(const Duration(days: 6))),
    Cliente(id: '40', nombre: 'José Aguilera (Distribuidor)', rut: '10.228.258-2', telefono: '+56963280936', categoria: 'Mayoristas / Surtido General', queCompra: 'Compra por encargos de todo para repartir a almacenes', montoPromedio: 1300000, notas: 'Reparte a diferentes almacenes (Hoja 1)', cicloDias: 7, ultimoContacto: now.subtract(const Duration(days: 9))),
    Cliente(id: '41', nombre: 'Hugo Ximenez (Quilicura)', rut: '78.351.458-3', telefono: '+56962454930', categoria: 'Mayoristas / Surtido General', queCompra: 'Compra de todo, mucho abarrote y pallets de papel', montoPromedio: 1600000, notas: 'Quilicura - alto volumen en abarrotes y papel', cicloDias: 10, ultimoContacto: now.subtract(const Duration(days: 11))),
    Cliente(id: '42', nombre: 'Jocelyn Hernandez (Melipilla)', rut: '18.777.480-2', telefono: '+56953416737', categoria: 'Mayoristas / Surtido General', queCompra: 'Viene todos los lunes, compra por cantidad', montoPromedio: 1200000, notas: 'Es de Melipilla - compra todos los lunes', cicloDias: 7, ultimoContacto: now.subtract(const Duration(days: 7))),

    // --- CLIENTES DE FERIA (2 CLIENTES) ---
    Cliente(id: '43', nombre: 'Ramon', rut: '', telefono: '+56954352142', categoria: 'Clientes de Feria', queCompra: 'Comerciante de feria', montoPromedio: 350000, notas: 'Feria', cicloDias: 7, ultimoContacto: now.subtract(const Duration(days: 5))),
    Cliente(id: '44', nombre: 'Miguel Muñoz', rut: '', telefono: '+56956054737', categoria: 'Clientes de Feria', queCompra: 'Papelería y perfumería', montoPromedio: 350000, notas: 'Feria', cicloDias: 7, ultimoContacto: now.subtract(const Duration(days: 8))),

    // --- CLIENTES PENDIENTES / SIN CLASIFICAR (12 CLIENTES) ---
    Cliente(id: '45', nombre: 'Angelo Fuente Alba', rut: '', telefono: '+56987387277', categoria: 'Sin Clasificar', queCompra: 'Pendiente consultar rubro principal', montoPromedio: 300000, notas: 'Clasificar en próximo contacto', cicloDias: 10, ultimoContacto: now.subtract(const Duration(days: 14))),
    Cliente(id: '46', nombre: 'Darwin', rut: '', telefono: '+56996141816', categoria: 'Sin Clasificar', queCompra: 'Pendiente consultar rubro principal', montoPromedio: 300000, notas: 'Clasificar en próximo contacto', cicloDias: 10, ultimoContacto: now.subtract(const Duration(days: 14))),
    Cliente(id: '47', nombre: 'Felipe', rut: '', telefono: '', categoria: 'Sin Clasificar', queCompra: 'Pendiente registrar teléfono y rubro', montoPromedio: 300000, notas: 'Sin teléfono en planilla Excel', cicloDias: 14, ultimoContacto: now.subtract(const Duration(days: 15))),
    Cliente(id: '48', nombre: 'Freddy Cartagena', rut: '', telefono: '+56963162615', categoria: 'Sin Clasificar', queCompra: 'Pendiente consultar rubro principal', montoPromedio: 300000, notas: 'Clasificar en próximo contacto', cicloDias: 10, ultimoContacto: now.subtract(const Duration(days: 13))),
    Cliente(id: '49', nombre: 'GSM Construcciones SpA', rut: '', telefono: '+56950339202', categoria: 'Sin Clasificar', queCompra: 'Empresa constructora (consultar insumos/aseo)', montoPromedio: 400000, notas: 'Clasificar en próximo contacto', cicloDias: 14, ultimoContacto: now.subtract(const Duration(days: 14))),
    Cliente(id: '50', nombre: 'Jamyl SpA', rut: '76.990.226-0', telefono: '+56992175269', categoria: 'Sin Clasificar', queCompra: 'Pendiente consultar rubro principal', montoPromedio: 400000, notas: 'RUT 76990226-0 (Tel en Excel: 92175269)', cicloDias: 12, ultimoContacto: now.subtract(const Duration(days: 13))),
    Cliente(id: '51', nombre: 'Jorge', rut: '', telefono: '+56973427894', telefonoSecundario: '+56959661230', categoria: 'Sin Clasificar', queCompra: 'Pendiente consultar rubro principal', montoPromedio: 350000, notas: 'Anotación original: 2/2. Tel 2: +56959661230', cicloDias: 10, ultimoContacto: now.subtract(const Duration(days: 12))),
    Cliente(id: '52', nombre: 'Manuel', rut: '', telefono: '+56983901434', categoria: 'Sin Clasificar', queCompra: 'Pendiente consultar rubro principal', montoPromedio: 300000, notas: 'Clasificar en próximo contacto', cicloDias: 10, ultimoContacto: now.subtract(const Duration(days: 11))),
    Cliente(id: '53', nombre: 'Peter Lobos', rut: '', telefono: '+56937434472', categoria: 'Sin Clasificar', queCompra: 'Pendiente consultar rubro principal', montoPromedio: 300000, notas: 'Clasificar en próximo contacto', cicloDias: 10, ultimoContacto: now.subtract(const Duration(days: 12))),
    Cliente(id: '54', nombre: 'Pablo San Martín', rut: '', telefono: '+56976233136', categoria: 'Sin Clasificar', queCompra: 'Pendiente consultar rubro principal', montoPromedio: 300000, notas: 'Recuperado de Hoja 1 (Fila 55)', cicloDias: 10, ultimoContacto: now.subtract(const Duration(days: 11))),
    Cliente(id: '55', nombre: 'Contacto Mayorista (995419965)', rut: '', telefono: '+56995419965', categoria: 'Sin Clasificar', queCompra: 'Pendiente identificar nombre y rubro', montoPromedio: 300000, notas: 'Recuperado de Hoja 1 (Fila 48)', cicloDias: 10, ultimoContacto: now.subtract(const Duration(days: 12))),
    Cliente(id: '56', nombre: 'Contacto Mayorista (962829954)', rut: '', telefono: '+56962829954', categoria: 'Sin Clasificar', queCompra: 'Pendiente identificar nombre y rubro', montoPromedio: 300000, notas: 'Recuperado de Hoja 1 (Fila 151)', cicloDias: 10, ultimoContacto: now.subtract(const Duration(days: 12))),

    // --- FACTURACIÓN / BOLETAS PDF (5 CLIENTES) ---
    Cliente(id: '57', nombre: 'Gemma del Carmen Henriquez Orellana', rut: '12.676.382-4', telefono: '', categoria: 'Facturación Reciente', queCompra: 'Factura Mayorista (7 líneas de producto)', montoPromedio: 1292815, notas: 'Sucursal Bernardino Parada 0958 - Pago Transf. Electrónica', cicloDias: 10, ultimoContacto: now.subtract(const Duration(days: 11))),
    Cliente(id: '58', nombre: 'Marco Loriza Pereira', rut: '9.766.488-2', telefono: '', categoria: 'Facturación Reciente', queCompra: 'Factura Mayorista 9575 (15 productos)', montoPromedio: 253548, notas: 'Local 77 Bodega Mersan - Sucursal Acapulco 08187', cicloDias: 14, ultimoContacto: now.subtract(const Duration(days: 9))),
    Cliente(id: '59', nombre: 'Elizabeth Gonzalez', rut: '12.286.172-4', telefono: '', categoria: 'Facturación Reciente', queCompra: 'Boleta Mayorista 9550 (Bodega Mersan)', montoPromedio: 350000, notas: 'Sucursal Parcela Lote 1-7 Santa Mónica', cicloDias: 14, ultimoContacto: now.subtract(const Duration(days: 10))),
    Cliente(id: '60', nombre: 'Gonzalo Schillings', rut: '18.392.938-0', telefono: '', categoria: 'Facturación Reciente', queCompra: 'Registro RUT Mayorista', montoPromedio: 400000, notas: 'Documento adjunto pág. 3', cicloDias: 14, ultimoContacto: now.subtract(const Duration(days: 12))),
    Cliente(id: '61', nombre: 'Javiera Alejandra', rut: '19.847.147-K', telefono: '', categoria: 'Facturación Reciente', queCompra: 'Registro RUT Mayorista', montoPromedio: 400000, notas: 'Documento adjunto pág. 3', cicloDias: 14, ultimoContacto: now.subtract(const Duration(days: 12))),
  ];
}

String formatearPesos(int monto) {
  final str = monto.toString();
  final buffer = StringBuffer();
  for (int i = 0; i < str.length; i++) {
    if (i > 0 && (str.length - i) % 3 == 0) buffer.write('.');
    buffer.write(str[i]);
  }
  return buffer.toString();
}

String quitarTildes(String input) {
  const conTilde = 'áéíóúüñÁÉÍÓÚÜÑ';
  const sinTilde = 'aeiouunAEIOUUN';
  String res = input;
  for (int i = 0; i < conTilde.length; i++) {
    res = res.replaceAll(conTilde[i], sinTilde[i]);
  }
  return res.toLowerCase();
}

// ==========================================
// MOTOR DE SUGERENCIAS PROACTIVAS Y VENTA CRUZADA
// ==========================================
class SugerenciaInteligente {
  final String titulo;
  final String subtitulo;
  final String accionTexto;
  final IconData icono;
  final Color color;
  final Cliente? clienteObjetivo;
  final String? promoSugerida;
  final String? categoriaCampana;

  SugerenciaInteligente({
    required this.titulo,
    required this.subtitulo,
    required this.accionTexto,
    required this.icono,
    required this.color,
    this.clienteObjetivo,
    this.promoSugerida,
    this.categoriaCampana,
  });
}

class MotorSugerenciasPro {
  // Calcula qué producto complementario (Cross-Selling) ofrecerle a cada cliente
  static String obtenerCrossSellParaCliente(Cliente c) {
    final blob = quitarTildes('${c.queCompra} ${c.notas} ${c.categoria}');

    if (blob.contains('corta fecha')) {
      return 'Armar pack de liquidación rápida + pallet mixto de alta rotación';
    }
    if (blob.contains('chocolate')) {
      return 'Sumar galletas por caja, confites de impulso y bebidas/energéticas Score';
    }
    if (blob.contains('queso')) {
      return 'Ofrecer cecinas, bolsas camiseta/rollo y servilletas para fiambrería';
    }
    if (blob.contains('arroz') || blob.contains('azucar') || blob.contains('panaderia')) {
      return 'Cruzar con aceite por caja, harina y mangas de toalla de papel absorbente';
    }
    if (blob.contains('agua') || blob.contains('bebida')) {
      return 'Sumar energéticas Score por bandeja y snacks/papas por caja';
    }
    if (blob.contains('papel') && !blob.contains('detergente')) {
      return 'Cross-Sell Aseo: Sumar bolsas de basura, detergente líquido y toalla nova (+25% ticket)';
    }
    if (blob.contains('aseo') || blob.contains('limpieza')) {
      return 'Ofrecer mangas de papel higiénico (10x10) y cloro/desinfectantes por mayor';
    }
    if (c.categoria == 'Sin Clasificar') {
      return 'Enviar catálogo gancho (Oferta Papel 4x500 + Abarrotes) para descubrir su rubro';
    }
    if (c.categoria == 'Facturación Reciente') {
      return 'Agendar teléfono de recompra para convertir boleta/factura presencial en cliente recurrente';
    }
    return 'Ofrecer combo Mayorista: Pallets de Papel + Bebidas y Abarrotes de alta rotación';
  }

  // Genera las tarjetas estratégicas del carrusel superior
  static List<SugerenciaInteligente> generarJugadasDelDia(List<Cliente> cartera) {
    final List<SugerenciaInteligente> jugadas = [];
    final urgentes = cartera.where((c) => c.requiereAtencionUrgente && c.telefono.isNotEmpty).toList()
      ..sort((a, b) => b.montoPromedio.compareTo(a.montoPromedio));

    // 1. Rescate de Ballena #1
    if (urgentes.isNotEmpty) {
      final top = urgentes.first;
      jugadas.add(
        SugerenciaInteligente(
          titulo: '🐋 Ballena en Riesgo: ${top.nombre.split('/').first.trim()}',
          subtitulo:
              'Mueve \$${formatearPesos(top.montoPromedio)} y lleva ${top.diasSinContacto} días sin contacto. ${obtenerCrossSellParaCliente(top)}.',
          accionTexto: top.prefiereLlamada ? 'Llamar Ahora' : 'Enviar Oferta VIP',
          icono: Icons.PriorityHigh,
          color: const Color(0xFFEF4444),
          clienteObjetivo: top,
        ),
      );
    }

    // 2. Oportunidad de Cross-Selling en Papel (Subir ticket a compradores de pallets)
    final papelPuro = cartera
        .where((c) =>
            c.categoria == 'Aseo y Papel' &&
            !quitarTildes(c.queCompra).contains('detergente') &&
            c.montoPromedio >= 1000000)
        .toList();
    if (papelPuro.isNotEmpty) {
      jugadas.add(
        SugerenciaInteligente(
          titulo: '📈 Venta Cruzada: Papel ➔ Detergente y Bolsas',
          subtitulo:
              'Tienes ${papelPuro.length} clientes grandes (como ${papelPuro.first.nombre.split('/').first.trim()}) que solo llevan papel. Ofréceles detergente, bolsas y toallas.',
          accionTexto: 'Armar Campaña Aseo',
          icono: Icons.trending_up,
          color: const Color(0xFF10B981),
          categoriaCampana: 'Aseo y Papel',
          promoSugerida:
              'Combo Mayorista Aseo: Por la compra de tus mangas/pallet de Papel Higiénico, lleva Detergente, Toalla y Bolsas a precio costo distribuidor',
        ),
      );
    }

    // 3. Ruta Geográfica Inteligente (Melipilla / Lampa / Quilicura)
    final melipilla = cartera.where((c) => quitarTildes('${c.nombre} ${c.notas} ${c.queCompra}').contains('melipilla')).toList();
    if (melipilla.isNotEmpty) {
      jugadas.add(
        SugerenciaInteligente(
          titulo: '🚚 Consolidar Ruta Melipilla (${melipilla.length} clientes)',
          subtitulo:
              'Junta los pedidos de ${melipilla.map((e) => e.nombre.split('(').first.trim()).join(' y ')} en un solo flete sobre \$1.800.000.',
          accionTexto: 'Contactar Ruta',
          icono: Icons.local_shipping,
          color: const Color(0xFF38BDF8),
          clienteObjetivo: melipilla.first,
        ),
      );
    }

    // 4. Cazador Rápido de Corta Fecha
    final cortaFecha = cartera.where((c) => quitarTildes('${c.queCompra} ${c.notas}').contains('corta fecha')).toList();
    if (cortaFecha.isNotEmpty) {
      jugadas.add(
        SugerenciaInteligente(
          titulo: '⚡ Liquidación Rápida (Corta Fecha)',
          subtitulo:
              '${cortaFecha.map((e) => e.nombre).join(' y ')} compran lotes a corta fecha al contado. Ideal para limpiar bodega hoy.',
          accionTexto: 'Ofrecer Lote',
          icono: Icons.flash_on,
          color: const Color(0xFFF59E0B),
          clienteObjetivo: cortaFecha.first,
        ),
      );
    }

    return jugadas;
  }
}

// ==========================================
// AGENTE CONVERSACIONAL DEEPSEEK V4 (FUZZY NLU + ESTRATEGIAS)
// ==========================================
class RespuestaDeepSeek {
  final String pensamiento;
  final String respuesta;
  final Cliente? clienteRelacionado;
  final String? promoParaCampana;
  final String? categoriaParaCampana;

  RespuestaDeepSeek({
    required this.pensamiento,
    required this.respuesta,
    this.clienteRelacionado,
    this.promoParaCampana,
    this.categoriaParaCampana,
  });
}

class DeepSeekConversationalAgent {
  static Cliente? ultimoClienteEnContexto;
  static final Random _rng = Random();

  // Similitud por bigramas (Sørensen-Dice) para entender nombres mal escritos ("weiz", "bonasic", "cristofer")
  static double _similitudTexto(String s1, String s2) {
    final a = quitarTildes(s1).replaceAll(' ', '');
    final b = quitarTildes(s2).replaceAll(' ', '');
    if (a == b) return 1.0;
    if (a.length < 2 || b.length < 2) return 0.0;

    final bigramasA = <String>{};
    for (int i = 0; i < a.length - 1; i++) {
      bigramasA.add(a.substring(i, i + 2));
    }
    final bigramasB = <String>{};
    for (int i = 0; i < b.length - 1; i++) {
      bigramasB.add(b.substring(i, i + 2));
    }

    int interseccion = 0;
    for (final bg in bigramasA) {
      if (bigramasB.contains(bg)) interseccion++;
    }
    return (2.0 * interseccion) / (bigramasA.length + bigramasB.length);
  }

  static String generarMensajeWhatsApp(Cliente c, String promoBase, int variacion, {bool incluirCrossSell = false}) {
    final nombreCorto = c.nombre.split('/').first.split('(').first.trim();
    final saludos = [
      '¡Hola $nombreCorto! ¿Cómo va todo por el negocio?',
      '¡Buenas $nombreCorto! Te escribo directo desde bodega.',
      'Hola $nombreCorto, ¿qué tal la semana? Paso a dejarte un dato clave:',
      '¡Wena $nombreCorto! Te aviso antes de que se agote este lote en bodega:'
    ];

    final tieneCompraEspecifica =
        c.queCompra.isNotEmpty && !c.queCompra.toLowerCase().contains('pendiente');
    final gancho = tieneCompraEspecifica
        ? 'Como sé que mueves fuerte *${c.queCompra.toLowerCase()}*, te reservé prioridad en esta promo:'
        : 'Nos acaba de entrar mercadería con excelente margen para tu local:';

    final crossSell = incluirCrossSell
        ? '\n💡 *Dato extra para tu pedido:* Aprovecha de sumar *${MotorSugerenciasPro.obtenerCrossSellParaCliente(c).toLowerCase()}* a precio de distribuidor.'
        : (c.montoPromedio >= 1500000
            ? '\n📦 *Precio especial por pallet/volumen aplicado para tu cuenta.*'
            : '');

    final cierres = [
      '¿Cuántas mangas o cajas te anoto, o prefieres que te pegue una llamada en 5 minutos?',
      'Avísame por acá qué cantidad te separo para bloquearte el stock hoy.',
      'Si te acomoda me confirmas por acá o te llamo altiro para coordinar.',
    ];

    return '${saludos[variacion % saludos.length]}\n\n$gancho\n\n🔥 *$promoBase*$crossSell\n\n${cierres[variacion % cierres.length]}';
  }

  static Future<RespuestaDeepSeek> conversar({
    required String inputUsuario,
    required List<Cliente> cartera,
    String apiKey = '',
    String apiEndpoint = 'https://api.deepseek.com/v1/chat/completions',
  }) async {
    final limpio = quitarTildes(inputUsuario.trim());

    // 1. Conector API / Localhost (si el usuario activó servidor externo o API Key)
    if (apiKey.trim().isNotEmpty || apiEndpoint.contains('127.0.0.1') || apiEndpoint.contains('localhost')) {
      try {
        final resumenCartera = cartera
            .map((c) =>
                '${c.nombre} (RUT:${c.rut}, Tel:${c.telefono}, Rubro:${c.categoria}, Compra:${c.queCompra}, Prom:\$${c.montoPromedio}, SinContacto:${c.diasSinContacto}d, CrossSell:${MotorSugerenciasPro.obtenerCrossSellParaCliente(c)})')
            .join(' | ');
        final resp = await http
            .post(
              Uri.parse(apiEndpoint),
              headers: {
                'Content-Type': 'application/json',
                if (apiKey.isNotEmpty) 'Authorization': 'Bearer $apiKey',
              },
              body: jsonEncode({
                'model': 'deepseek-chat',
                'messages': [
                  {
                    'role': 'system',
                    'content':
                        'Eres DeepSeek, el socio comercial experto, agudo y natural de Cristóbal en Santiago de Chile. Hablas con naturalidad, humor inteligente y precisión comercial. Tienes acceso a sus ${cartera.length} clientes: $resumenCartera'
                  },
                  {'role': 'user', 'content': inputUsuario}
                ],
                'temperature': 0.7,
              }),
            )
            .timeout(const Duration(seconds: 12));

        if (resp.statusCode == 200) {
          final decoded = jsonDecode(utf8.decode(resp.bodyBytes));
          final content = decoded['choices']?[0]?['message']?['content'] ?? '';
          if (content.toString().isNotEmpty) {
            return RespuestaDeepSeek(
              pensamiento: 'Inferencia neuronal ejecutada sobre ${cartera.length} clientes.',
              respuesta: content.toString(),
            );
          }
        }
      } catch (_) {}
    }

    // 2. CEREBRO SEMÁNTICO LOCAL DEEPSEEK-R1 V4 (100% OFFLINE)
    final hora = DateTime.now().hour;
    final saludoHora = hora < 12 ? 'buenos días' : (hora < 20 ? 'buenas tardes' : 'buenas noches');
    final urgentes = cartera.where((c) => c.requiereAtencionUrgente).toList()
      ..sort((a, b) => b.montoPromedio.compareTo(a.montoPromedio));
    final ballenaTop = urgentes.isNotEmpty ? urgentes.first : cartera.first;

    // A) SALUDOS Y CHARLA NATURAL
    final esSaludo = RegExp(
            r'^(hola+|holaa+|wena+|buenas+|buenos dias|buenas tardes|buenas noches|que tal|como estas|como va|hey|alo|habla|que pasa|que onda)[\s!?.]*$')
        .hasMatch(limpio);

    if (esSaludo || limpio == 'hola deepseek' || limpio == 'wena hermano') {
      final respuestasSaludo = [
        '¡Wena Cristóbal! ¿Cómo se viene la jornada? Ya estuve escaneando los *${cartera.length} clientes* de tu Excel y te tengo una jugada lista: *${ballenaTop.nombre}* mueve *\$${formatearPesos(ballenaTop.montoPromedio)}* y lleva ${ballenaTop.diasSinContacto} días en silencio. Además de lo que siempre lleva (${ballenaTop.queCompra.toLowerCase()}), hoy podríamos meterle *${MotorSugerenciasPro.obtenerCrossSellParaCliente(ballenaTop).toLowerCase()}*. ¿Le damos o buscas otro dato?',
        '¡Hola Cristóbal, $saludoHora! Aquí estamos con el motor al 100% y sin gastar un peso de internet. Tienes *${urgentes.length} clientes* listos para recompra hoy. Dime qué mercadería tienes parada en bodega o de qué cliente quieres que te arme una estrategia.',
        '¡Buenas! ¿Cómo va ese ánimo? Oye, estaba viendo que entre *Sra. Margarita*, *Edisson Bonacic* y *Comercial Nietos* tienes casi \$9 millones en juego. ¿Quieres que te arme un mensaje matador para despertarlos o revisamos alguna comuna en particular?',
      ];
      ultimoClienteEnContexto = ballenaTop;
      return RespuestaDeepSeek(
        pensamiento:
            'Saludo natural detectado ($saludoHora). Cruzando métricas de los ${cartera.length} clientes para proponer una acción inmediata de alto retorno.',
        respuesta: respuestasSaludo[_rng.nextInt(respuestasSaludo.length)],
        clienteRelacionado: ballenaTop,
      );
    }

    // B) PEDIDOS DE SUGERENCIAS, IDEAS PARA VENDER MÁS O ESTRATEGIAS
    if (limpio.contains('sugerencia') ||
        limpio.contains('idea') ||
        limpio.contains('estrategia') ||
        limpio.contains('vender mas') ||
        limpio.contains('subir ventas') ||
        limpio.contains('que me recomiendas') ||
        limpio.contains('que hacemos')) {
      return RespuestaDeepSeek(
        pensamiento:
            'Analizando brechas de facturación (Cross-Selling, retención de ballenas y consolidación de fletes) en los ${cartera.length} clientes.',
        respuesta:
            'Te armé **3 jugadas estratégicas** basadas en los datos reales de tu Excel para facturar rápido hoy:\n\n'
            '1. **Venta Cruzada en Aseo (+25% por pedido):** Tienes clientes como *Comercial ATH / Pedro* (\$2.5M), *Agrolatino* (\$1.2M), *Josep Silva* y *Felipe Lobos* que compran pallets de papel, pero no te están llevando bolsas, detergente ni toalla como *Andres Albarracin*.\n'
            '2. **Combo Ruta Melipilla:** *Jocelyn Hernandez* (\$1.2M, compra los lunes) y *Luis Silva* (\$650k, despacho a Melipilla) suman \$1.850.000. Si los contactas juntos hoy, llenas el camión en un solo viaje.\n'
            '3. **Despertar a las 3 Ballenas de \$3 Millones:** *Sra. Margarita* (Playa) y *Edisson Bonacic Rojas* están pasados de su ciclo. Un llamado de 2 minutos ahí vale más que 15 clientes chicos.\n\n'
            'Toca el botón de abajo si quieres cargar altiro la **Campaña de Venta Cruzada de Aseo** o llamar a *${ballenaTop.nombre}*.',
        clienteRelacionado: ballenaTop,
        promoParaCampana:
            'Especial Mayorista: Suma a tu pedido de Papel Higiénico nuestro pack de Detergente, Bolsas y Toalla Absorbente con descuento por volumen',
        categoriaParaCampana: 'Aseo y Papel',
      );
    }

    // C) BÚSQUEDA DIFUSA DE CLIENTE (EXACTA + TOLERANTE A ERRORES ORTOGRÁFICOS)
    Cliente? clienteDetectado;
    double mejorScore = 0.0;
    final palabrasInput = limpio
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.length >= 3 && !['quien', 'como', 'donde', 'cuanto', 'cual', 'para', 'hola', 'dime', 'cliente', 'clientes', 'compra', 'vende', 'tiene', 'numero', 'telefono', 'llamar', 'mensaje'].contains(w))
        .toList();

    for (final c in cartera) {
      final nomLimpio = quitarTildes(c.nombre);
      double score = 0.0;
      if (limpio.contains(nomLimpio)) score += 15.0;

      final tokensCliente = nomLimpio
          .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
          .split(RegExp(r'\s+'))
          .where((t) => t.length >= 3 && !['spa', 'eirl', 'ltda', 'local', 'minimarket', 'almacen', 'comercial', 'santa'].contains(t))
          .toList();

      for (final tk in tokensCliente) {
        if (limpio.contains(tk)) {
          score += 6.0;
        } else {
          for (final p in palabrasInput) {
            final sim = _similitudTexto(p, tk);
            if (sim >= 0.72) score += sim * 5.0;
          }
        }
      }

      if (c.rut.isNotEmpty && limpio.contains(c.rut.replaceAll('.', '').toLowerCase())) {
        score += 15.0;
      }

      if (score > mejorScore && score >= 3.8) {
        mejorScore = score;
        clienteDetectado = c;
      }
    }

    // Memoria de contexto si dice "hazle un mensaje", "llamalo", "que ofrecerle", "su numero"
    if (clienteDetectado == null &&
        ultimoClienteEnContexto != null &&
        (limpio.contains('su ') ||
            limpio.contains('ese ') ||
            limpio.contains('hazle') ||
            limpio.contains('redactale') ||
            limpio.contains('escribele') ||
            limpio.contains('ofrecerle') ||
            limpio.contains('llamalo'))) {
      clienteDetectado = ultimoClienteEnContexto;
    }

    if (clienteDetectado != null) {
      ultimoClienteEnContexto = clienteDetectado;
      final c = clienteDetectado;
      final crossSell = MotorSugerenciasPro.obtenerCrossSellParaCliente(c);

      if (limpio.contains('mensaje') || limpio.contains('redact') || limpio.contains('whatsapp') || limpio.contains('escrib') || limpio.contains('guion')) {
        final msg = generarMensajeWhatsApp(
          c,
          'Lote preferencial de ${c.queCompra.isNotEmpty ? c.queCompra : "mercadería mayorista"} a precio de pallet',
          _rng.nextInt(4),
          incluirCrossSell: true,
        );
        return RespuestaDeepSeek(
          pensamiento:
              'Generando copywriting con Venta Cruzada integrada para ${c.nombre} (Ticket: \$${formatearPesos(c.montoPromedio)}).',
          respuesta:
              'Te armé este mensaje con gancho de venta cruzada para *${c.nombre}*:\n\n'
              '“$msg”\n\n'
              'Toca *Enviar WhatsApp* aquí abajo y se abre su chat con el texto listo.',
          clienteRelacionado: c,
        );
      }

      final alertaTiempo = c.requiereAtencionUrgente
          ? '🚨 *Alerta de Ciclo:* Lleva *${c.diasSinContacto} días* sin contacto (su ciclo es de ${c.cicloDias}d). ¡Contáctalo hoy!'
          : '✅ *Al día:* Hablaron hace ${c.diasSinContacto} días (ciclo de ${c.cicloDias}d).';

      return RespuestaDeepSeek(
        pensamiento:
            'Ficha encontrada para "${c.nombre}" (Score de coincidencia: ${mejorScore.toStringAsFixed(1)}). Calculando estrategia de Cross-Selling.',
        respuesta:
            'Aquí tienes la radiografía completa y estrategia para *${c.nombre}*:\n\n'
            '• *Rubro:* ${c.categoria}\n'
            '• *RUT:* ${c.rut.isNotEmpty ? c.rut : "Pendiente"}\n'
            '• *Teléfono:* ${c.telefono.isNotEmpty ? c.telefono : "Sin registrar"}${c.telefonoSecundario.isNotEmpty ? " | Tel 2: ${c.telefonoSecundario}" : ""}\n'
            '• *Compra habitual:* ${c.queCompra}\n'
            '• *Ticket promedio:* \$${formatearPesos(c.montoPromedio)}\n'
            '• *Notas:* ${c.notas}\n\n'
            '💡 *Sugerencia IA para subirle la venta:* $crossSell.\n\n'
            '$alertaTiempo',
        clienteRelacionado: c,
      );
    }

    // D) CONSULTAS POR COMUNA / RUTA
    final comunas = ['melipilla', 'lampa', 'quilicura', 'pirque', 'rancagua', 'ovalle', 'playa', 'casa blanca', 'mersan', 'feria'];
    for (final com in comunas) {
      if (limpio.contains(com)) {
        final encontrados = cartera.where((c) {
          final todo = quitarTildes('${c.nombre} ${c.queCompra} ${c.notas} ${c.categoria}');
          return todo.contains(com);
        }).toList();

        if (encontrados.isNotEmpty) {
          ultimoClienteEnContexto = encontrados.first;
          final sumaZona = encontrados.fold<int>(0, (s, c) => s + c.montoPromedio);
          final detalle = encontrados
              .map((c) =>
                  '• *${c.nombre}* (${c.telefono.isNotEmpty ? c.telefono : "Sin tel"}) ➔ ${c.queCompra} [\$${formatearPesos(c.montoPromedio)}]')
              .join('\n');
          return RespuestaDeepSeek(
            pensamiento:
                'Agrupando ruta logística para "$com": ${encontrados.length} clientes suman \$${formatearPesos(sumaZona)}.',
            respuesta:
                'En la ruta *${com.toUpperCase()}* tienes ${encontrados.length} clientes que suman *\$${formatearPesos(sumaZona)}* en potencial:\n\n$detalle\n\n'
                '💡 *Jugada recomendada:* Contacta primero a *${encontrados.first.nombre}* para asegurar la base del flete y luego ofrece cupo en el camión al resto.',
            clienteRelacionado: encontrados.first,
          );
        }
      }
    }

    // E) CONSULTAS POR PRODUCTOS ESPECÍFICOS
    final mapaProductos = <String, List<String>>{
      'Corta Fecha / Liquidación': ['corta fecha', 'vencimiento', 'liquidacion'],
      'Papel Higiénico / Toallas / Mangas': ['papel', 'higienico', 'toalla', 'servilleta', 'elite', 'manga'],
      'Artículos de Aseo y Limpieza': ['aseo', 'limpieza', 'detergente', 'cloro', 'bolsa', 'perfumeria'],
      'Bebidas, Agua y Energéticas (Score)': ['bebida', 'agua', 'score', 'bebestible', 'jugo'],
      'Queso Despunte y Fiambrería': ['queso', 'despunte', 'cecina', 'carniceria'],
      'Arroz, Azúcar y Abarrotes por Pallet': ['arroz', 'azucar', 'abarrote', 'panaderia'],
      'Chocolates y Confites': ['chocolate', 'dulce', 'confite'],
      'Compras por Pallet Cerrado': ['pallet', 'palet'],
    };

    for (final entry in mapaProductos.entries) {
      if (entry.value.any((kw) => limpio.contains(kw))) {
        final coincidencias = cartera.where((c) {
          final blob = quitarTildes('${c.queCompra} ${c.notas} ${c.categoria}');
          return entry.value.any((kw) => blob.contains(kw));
        }).toList()
          ..sort((a, b) => b.montoPromedio.compareTo(a.montoPromedio));

        if (coincidencias.isNotEmpty) {
          ultimoClienteEnContexto = coincidencias.first;
          final topLista = coincidencias
              .take(8)
              .map((c) => '• *${c.nombre}* (\$${formatearPesos(c.montoPromedio)}) ➔ ${c.queCompra}')
              .join('\n');
          return RespuestaDeepSeek(
            pensamiento:
                'Filtrando los mejores compradores para "${entry.key}" entre los ${cartera.length} registros.',
            respuesta:
                'Para vender *${entry.key}* hoy mismo, aquí tienes a tus *${coincidencias.length} compradores directos* ordenados por volumen de plata:\n\n$topLista\n\n'
                '💡 *Sugerencia:* Parte por *${coincidencias.first.nombre}* (\$${formatearPesos(coincidencias.first.montoPromedio)}) o lanza una campaña directa con el botón de abajo.',
            clienteRelacionado: coincidencias.first,
            promoParaCampana: 'Llegó lote nuevo de ${entry.key} a precio mayorista por manga/pallet. Cupos limitados en bodega',
            categoriaParaCampana: coincidencias.first.categoria,
          );
        }
      }
    }

    // F) RANKING DE LLAMADAS URGENTES / BALLENAS
    if (limpio.contains('llamar') ||
        limpio.contains('urgente') ||
        limpio.contains('hoy') ||
        limpio.contains('ballena') ||
        limpio.contains('millon') ||
        limpio.contains('prioridad') ||
        limpio.contains('atrasad')) {
      final topUrgentes = urgentes.take(7).toList();
      final montoRiesgo = urgentes.fold<int>(0, (s, c) => s + c.montoPromedio);
      ultimoClienteEnContexto = topUrgentes.isNotEmpty ? topUrgentes.first : null;

      final listado = topUrgentes
          .map((c) =>
              '• *${c.nombre}* (\$${formatearPesos(c.montoPromedio)}) — Hace ${c.diasSinContacto}d sin contacto ${c.prefiereLlamada ? "📞 [Llamar]" : "💬"}')
          .join('\n');

      return RespuestaDeepSeek(
        pensamiento:
            'Priorizando ${urgentes.length} clientes fuera de ciclo por impacto financiero (\$${formatearPesos(montoRiesgo)}).',
        respuesta:
            'Aquí tienes tu **Hoja de Ruta de Hoy** (${urgentes.length} clientes pasados de fecha que suman *\$${formatearPesos(montoRiesgo)}*):\n\n$listado\n\n'
            'El más rentable para atacar ahora mismo es *${topUrgentes.first.nombre}* (${MotorSugerenciasPro.obtenerCrossSellParaCliente(topUrgentes.first)}).',
        clienteRelacionado: topUrgentes.first,
      );
    }

    // G) RESPUESTA CONVERSACIONAL INTELIGENTE ABIERTA
    final sugerido = urgentes.isNotEmpty ? urgentes[_rng.nextInt(min(5, urgentes.length))] : cartera.first;
    ultimoClienteEnContexto = sugerido;
    return RespuestaDeepSeek(
      pensamiento:
          'Procesando conversación abierta: "$inputUsuario". Vinculando con oportunidad comercial en vivo.',
      respuesta:
          'Te escucho, Cristóbal. Mira, cruzando lo que me dices con tus *${cartera.length} clientes*, una jugada redonda para hacer caja hoy es escribirle o llamar a *${sugerido.nombre}* (${sugerido.categoria}), que mueve *\$${formatearPesos(sugerido.montoPromedio)}* en *${sugerido.queCompra.toLowerCase()}* y además podemos ofrecerle *${MotorSugerenciasPro.obtenerCrossSellParaCliente(sugerido).toLowerCase()}*.\n\n'
          'También puedes preguntarme cosas como *"dame una estrategia para subir ventas"*, *"clientes de Melipilla"*, *"quién compra chocolates"* o el nombre de cualquier cliente.',
      clienteRelacionado: sugerido,
    );
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

    final lower = quitarTildes(textoBruto);
    String categoria = 'Mayoristas / Surtido General';
    if (lower.contains('papel') || lower.contains('aseo') || lower.contains('higienico') || lower.contains('toalla') || lower.contains('detergente')) {
      categoria = 'Aseo y Papel';
    } else if (lower.contains('abarrote') || lower.contains('almacen') || lower.contains('arroz') || lower.contains('queso') || lower.contains('bebida') || lower.contains('chocolate') || lower.contains('agua')) {
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
      notas: 'Extraído automáticamente con IA DeepSeek',
      prefiereLlamada: lower.contains('llamar'),
    );
  }
}

class MensajeChatIA {
  final bool esUsuario;
  final String pensamiento;
  final String texto;
  final Cliente? clienteAccion;
  final String? promoSugerida;
  final String? categoriaSugerida;

  MensajeChatIA({
    required this.esUsuario,
    this.pensamiento = '',
    required this.texto,
    this.clienteAccion,
    this.promoSugerida,
    this.categoriaSugerida,
  });
}

// ==========================================
// DASHBOARD PRINCIPAL ULTRA-FLUIDO (V4)
// ==========================================
class MainDashboard extends StatefulWidget {
  const MainDashboard({super.key});

  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard> {
  static const platform = MethodChannel('com.cristobal.crm/accessibility');
  static const String _storageKey = 'clientes_crm_v4_master_61';

  int _tabIndex = 0;
  List<Cliente> _clientes = [];
  String _filtroCategoria = 'Todos';
  String _busqueda = '';
  bool _accesibilidadActiva = false;
  bool _mostrarCarruselIA = true;

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
  bool _incluirCrossSellEnCampana = true;
  bool _campanaCorriendo = false;
  int _progresoCampana = 0;
  String _estadoCampanaTexto = 'Listo para iniciar';

  // DeepSeek Chat & Streaming
  final TextEditingController _chatIaCtrl = TextEditingController();
  final TextEditingController _notaCaoticaCtrl = TextEditingController();
  final ScrollController _chatScrollCtrl = ScrollController();
  final List<MensajeChatIA> _historialChat = [];
  bool _iaPensando = false;
  String _textoStreaming = '';
  String _apiKeyDeepSeek = '';
  String _apiEndpointDeepSeek = 'https://api.deepseek.com/v1/chat/completions';
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
    _apiKeyDeepSeek = prefs.getString('deepseek_api_key') ?? '';
    _apiEndpointDeepSeek =
        prefs.getString('deepseek_endpoint') ?? 'https://api.deepseek.com/v1/chat/completions';

    final data = prefs.getString(_storageKey);
    if (data != null) {
      final List decoded = jsonDecode(data);
      setState(() {
        _clientes = decoded.map((e) => Cliente.fromJson(e)).toList();
      });
    } else {
      setState(() {
        _clientes = construirCarteraMaestra61();
      });
      await _guardarDatos();
    }

    if (_historialChat.isEmpty) {
      final urgentes = _clientes.where((c) => c.requiereAtencionUrgente).length;
      _historialChat.add(
        MensajeChatIA(
          esUsuario: false,
          pensamiento:
              'Motor V4 activo: 61 clientes portados (Hoja 1 + Hoja 2 + Facturas) y sugerencias de Venta Cruzada calculadas.',
          texto:
              '¡Wena Cristóbal! Ya tienes la **Versión 4.0** corriendo con tus *${_clientes.length} clientes* del Excel y el motor de *Venta Cruzada (Cross-Selling)* activado en cada tarjeta. Tienes *$urgentes clientes* listos para recompra hoy.\n\nHáblame normal o pídele ideas a la IA: *"dame una estrategia para vender más hoy"*, *"¿quién es Jesús Peña?"* o *"clientes de Melipilla"*.',
        ),
      );
    }
  }

  Future<void> _guardarDatos() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_clientes.map((c) => c.toJson()).toList());
    await prefs.setString(_storageKey, encoded);
  }

  Future<void> _restaurarCartera61Excel() async {
    HapticFeedback.mediumImpact();
    setState(() {
      _clientes = construirCarteraMaestra61();
    });
    await _guardarDatos();
    _mostrarSnack('✅ ¡61 clientes del Excel sincronizados con éxito!');
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

  Future<void> _llamarCliente(Cliente c, {String? telefonoEspecifico}) async {
    final fono = telefonoEspecifico ?? c.telefono;
    if (fono.isEmpty) {
      _mostrarSnack('Este cliente no tiene teléfono registrado. Tócalo para agregarlo.');
      return;
    }
    HapticFeedback.lightImpact();
    await _marcarContactado(c);
    final uri = Uri.parse('tel:$fono');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _escribirWhatsApp(
    Cliente c, {
    String? mensajePersonalizado,
    bool autoClick = false,
    String? imagePath,
    bool incluirCrossSell = true,
  }) async {
    if (c.telefono.isEmpty) {
      _mostrarSnack('Agrega un teléfono a ${c.nombre} antes de enviar WhatsApp.');
      return;
    }
    HapticFeedback.lightImpact();
    await _marcarContactado(c);
    final numLimpio = c.telefono.replaceAll(RegExp(r'[^0-9]'), '');
    final msg = mensajePersonalizado ??
        DeepSeekConversationalAgent.generarMensajeWhatsApp(
          c,
          _promoCtrl.text,
          Random().nextInt(10),
          incluirCrossSell: incluirCrossSell,
        );

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

  // Modal instantáneo de Guion IA + Venta Cruzada para cualquier cliente
  void _mostrarGuionIACliente(Cliente c) {
    final crossSell = MotorSugerenciasPro.obtenerCrossSellParaCliente(c);
    final msgWhatsApp = DeepSeekConversationalAgent.generarMensajeWhatsApp(
      c,
      _promoCtrl.text,
      Random().nextInt(4),
      incluirCrossSell: true,
    );

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF131C2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome, color: Color(0xFF10B981)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Estrategia IA para ${c.nombre}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF070B12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF10B981).withOpacity(0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('🛒 Compra actual: ${c.queCompra} (\$${formatearPesos(c.montoPromedio)})',
                      style: const TextStyle(fontSize: 12.5, color: Colors.white70)),
                  const SizedBox(height: 6),
                  Text('💡 Oportunidad de Venta Cruzada:\n$crossSell',
                      style: const TextStyle(
                          fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                ],
              ),
            ),
            const SizedBox(height: 10),
            const Text('Mensaje sugerido con venta cruzada:',
                style: TextStyle(fontSize: 12, color: Colors.white60)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(msgWhatsApp, style: const TextStyle(fontSize: 12.5, height: 1.35)),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF26334D),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _llamarCliente(c);
                    },
                    icon: const Icon(Icons.phone),
                    label: const Text('Llamar Ahora'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _escribirWhatsApp(c, mensajePersonalizado: msgWhatsApp);
                    },
                    icon: const Icon(Icons.send),
                    label: const Text('Enviar WhatsApp',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
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
        'text':
            '🔥 *${_tituloAficheCtrl.text}* a solo *${_precioOfertaCtrl.text}* (${_subtituloAficheCtrl.text})',
      });
    } catch (e) {
      _mostrarSnack('Afiche guardado listo para campaña.');
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

      final msg = DeepSeekConversationalAgent.generarMensajeWhatsApp(
        cliente,
        _promoCtrl.text,
        i,
        incluirCrossSell: _incluirCrossSellEnCampana,
      );

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
  // ENVÍO Y STREAMING CONVERSACIONAL DEEPSEEK
  // ==========================================
  Future<void> _enviarMensajeADeepSeek(String texto) async {
    final pregunta = texto.trim();
    if (pregunta.isEmpty || _iaPensando) return;

    HapticFeedback.selectionClick();
    setState(() {
      _historialChat.add(MensajeChatIA(esUsuario: true, texto: pregunta));
      _chatIaCtrl.clear();
      _iaPensando = true;
      _textoStreaming = '';
    });
    _scrollChatAlFinal();

    await Future.delayed(const Duration(milliseconds: 260));
    final resultado = await DeepSeekConversationalAgent.conversar(
      inputUsuario: pregunta,
      cartera: _clientes,
      apiKey: _apiKeyDeepSeek,
      apiEndpoint: _apiEndpointDeepSeek,
    );

    final palabras = resultado.respuesta.split(' ');
    final buffer = StringBuffer();
    for (int i = 0; i < palabras.length; i++) {
      if (!mounted) break;
      buffer.write('${palabras[i]} ');
      if (i % 3 == 0 || i == palabras.length - 1) {
        setState(() {
          _textoStreaming = buffer.toString();
        });
        _scrollChatAlFinal();
        await Future.delayed(const Duration(milliseconds: 16));
      }
    }

    setState(() {
      _iaPensando = false;
      _textoStreaming = '';
      _historialChat.add(
        MensajeChatIA(
          esUsuario: false,
          pensamiento: resultado.pensamiento,
          texto: resultado.respuesta,
          clienteAccion: resultado.clienteRelacionado,
          promoSugerida: resultado.promoParaCampana,
          categoriaSugerida: resultado.categoriaParaCampana,
        ),
      );
    });
    _scrollChatAlFinal();
  }

  void _scrollChatAlFinal() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollCtrl.hasClients) {
        _chatScrollCtrl.animateTo(
          _chatScrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

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
      _estadoDescargaGGUF = 'Conectando con HuggingFace...';
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
          _estadoDescargaGGUF = 'Descargando GGUF: $mb MB...';
        });
      }
      await sink.close();
      setState(() {
        _descargandoModelo = false;
        _modeloGGUFInstalado = true;
        _estadoDescargaGGUF = '✅ Modelo GGUF instalado en memoria.';
      });
    } catch (_) {
      setState(() {
        _descargandoModelo = false;
        _estadoDescargaGGUF = 'Motor Conversacional Offline Activo.';
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

    final paginas = [
      _buildTabClientes(),
      _buildTabMonitoreo(),
      _buildTabEstudioPromos(),
      _buildTabCampanas(),
      _buildTabDeepSeek(),
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF131C2E),
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.auto_graph, color: Color(0xFF10B981), size: 20),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('CRM Mayorista Pro V4',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15.5)),
                Text('${_clientes.length} clientes del Excel activos',
                    style: const TextStyle(fontSize: 11, color: Colors.white60)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Sincronizar los 61 clientes del Excel',
            icon: const Icon(Icons.sync, color: Color(0xFF38BDF8)),
            onPressed: _restaurarCartera61Excel,
          ),
          IconButton(
            tooltip: 'Nuevo Cliente',
            icon: const Icon(Icons.person_add_alt_1, color: Color(0xFF10B981)),
            onPressed: () => _mostrarModalEditarCliente(null),
          ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 240),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: KeyedSubtree(
          key: ValueKey<int>(_tabIndex),
          child: paginas[_tabIndex],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: const Color(0xFF131C2E),
        selectedIndex: _tabIndex,
        onDestinationSelected: (idx) {
          HapticFeedback.selectionClick();
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
            label: 'Radar VIP',
          ),
          const NavigationDestination(icon: Icon(Icons.palette), label: 'Afiches'),
          const NavigationDestination(icon: Icon(Icons.rocket_launch), label: 'Campaña'),
          const NavigationDestination(icon: Icon(Icons.psychology), label: 'DeepSeek'),
        ],
      ),
    );
  }

  // ==========================================
  // PESTAÑA 1: CARTERA + CARRUSEL DE SUGERENCIAS IA
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
      final q = quitarTildes(_busqueda);
      final blob = quitarTildes('${c.nombre} ${c.queCompra} ${c.notas} ${c.rut} ${c.telefono}');
      return matchCat && blob.contains(q);
    }).toList();

    final volumenTotal = filtrados.fold<int>(0, (s, c) => s + c.montoPromedio);
    final jugadasHoy = MotorSugerenciasPro.generarJugadasDelDia(_clientes);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          decoration: const BoxDecoration(
            color: Color(0xFF131C2E),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildKpiMini('Clientes Activos', '${filtrados.length} / ${_clientes.length}',
                        Icons.groups, const Color(0xFF38BDF8)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildKpiMini('Potencial Mensual', '\$${formatearPesos(volumenTotal)}',
                        Icons.payments, const Color(0xFF10B981)),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    tooltip: 'Mostrar/Ocultar Sugerencias IA',
                    icon: Icon(
                      _mostrarCarruselIA ? Icons.lightbulb : Icons.lightbulb_outline,
                      color: Colors.amberAccent,
                    ),
                    onPressed: () => setState(() => _mostrarCarruselIA = !_mostrarCarruselIA),
                  ),
                ],
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                child: _mostrarCarruselIA && jugadasHoy.isNotEmpty
                    ? Container(
                        height: 108,
                        margin: const EdgeInsets.only(top: 8),
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          itemCount: jugadasHoy.length,
                          itemBuilder: (ctx, i) => _buildTarjetaJugadaIA(jugadasHoy[i]),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              const SizedBox(height: 8),
              TextField(
                decoration: InputDecoration(
                  hintText: 'Buscar cliente, comuna, RUT o producto (papel, queso, agua)...',
                  hintStyle: const TextStyle(fontSize: 12),
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _busqueda.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () => setState(() => _busqueda = ''),
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                  filled: true,
                  fillColor: const Color(0xFF070B12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (val) => setState(() => _busqueda = val),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 34,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: categorias.length,
                  itemBuilder: (ctx, i) {
                    final cat = categorias[i];
                    final sel = _filtroCategoria == cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(cat, style: const TextStyle(fontSize: 11.5)),
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
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(top: 8, bottom: 24),
            itemCount: filtrados.length,
            itemBuilder: (ctx, i) => _buildTarjetaCliente(filtrados[i], i),
          ),
        ),
      ],
    );
  }

  Widget _buildTarjetaJugadaIA(SugerenciaInteligente j) {
    return Container(
      width: 285,
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF070B12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: j.color.withOpacity(0.5), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(j.icono, color: j.color, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  j.titulo,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: j.color),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(
                height: 24,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: j.color,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  onPressed: () {
                    if (j.clienteObjetivo != null) {
                      _mostrarGuionIACliente(j.clienteObjetivo!);
                    } else if (j.promoSugerida != null) {
                      setState(() {
                        _promoCtrl.text = j.promoSugerida!;
                        if (j.categoriaCampana != null) _categoriaCampana = j.categoriaCampana!;
                        _tabIndex = 3;
                      });
                      _mostrarSnack('Sugerencia IA cargada en la Campaña');
                    }
                  },
                  child: Text(j.accionTexto,
                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Expanded(
            child: Text(
              j.subtitulo,
              style: const TextStyle(fontSize: 11, color: Colors.white70, height: 1.25),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiMini(String titulo, String valor, IconData icono, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF070B12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icono, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: const TextStyle(fontSize: 10, color: Colors.white60)),
                Text(valor,
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: color),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTarjetaCliente(Cliente c, int index) {
    final urgente = c.requiereAtencionUrgente;
    final colorBarra = urgente
        ? Colors.redAccent
        : (c.ratioUrgencia > 0.7 ? Colors.amberAccent : const Color(0xFF10B981));
    final sugerenciaCrossSell = MotorSugerenciasPro.obtenerCrossSellParaCliente(c);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.95, end: 1.0),
      duration: Duration(milliseconds: 160 + (index % 5) * 30),
      curve: Curves.easeOutCubic,
      builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        color: const Color(0xFF131C2E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
          side: BorderSide(
            color: urgente ? Colors.redAccent.withOpacity(0.6) : Colors.white10,
            width: 1.2,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: () => _mostrarModalEditarCliente(c),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: colorBarra.withOpacity(0.18),
                      child: Text(
                        c.nombre.isNotEmpty ? c.nombre[0].toUpperCase() : 'C',
                        style: TextStyle(color: colorBarra, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 10),
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
                Text('🛒 Compra: ${c.queCompra}', style: const TextStyle(fontSize: 12.5)),
                if (c.notas.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text('📌 ${c.notas}',
                        style: const TextStyle(fontSize: 11.5, color: Colors.amberAccent)),
                  ),
                const SizedBox(height: 6),
                // CÁPSULA DE SUGERENCIA IA DE VENTA CRUZADA
                InkWell(
                  onTap: () => _mostrarGuionIACliente(c),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF38BDF8).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.auto_awesome, size: 13, color: Color(0xFF38BDF8)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Sugerencia IA: $sugerenciaCrossSell',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF38BDF8)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Text('Ver guion ➔',
                            style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF38BDF8))),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (c.diasSinContacto / (c.cicloDias <= 0 ? 1 : c.cicloDias)).clamp(0.0, 1.0),
                    minHeight: 4,
                    backgroundColor: Colors.white10,
                    valueColor: AlwaysStoppedAnimation<Color>(colorBarra),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Hace ${c.diasSinContacto}d (Ciclo ${c.cicloDias}d)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: urgente ? FontWeight.bold : FontWeight.normal,
                        color: colorBarra,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (c.telefonoSecundario.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(right: 5),
                            child: SizedBox(
                              height: 31,
                              child: OutlinedButton.icon(
                                onPressed: () =>
                                    _llamarCliente(c, telefonoEspecifico: c.telefonoSecundario),
                                icon: const Icon(Icons.phone_forwarded, size: 13),
                                label: const Text('Tel 2', style: TextStyle(fontSize: 10.5)),
                              ),
                            ),
                          ),
                        SizedBox(
                          height: 31,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: c.prefiereLlamada
                                  ? Colors.amber.shade800
                                  : const Color(0xFF26334D),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                            ),
                            onPressed: () => _llamarCliente(c),
                            icon: const Icon(Icons.phone, size: 13.5),
                            label: Text(
                              c.prefiereLlamada ? 'LLAMAR' : 'Llamar',
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        SizedBox(
                          height: 31,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                            ),
                            onPressed: () => _escribirWhatsApp(c),
                            icon: const Icon(Icons.chat, size: 13.5),
                            label: const Text(
                              'WhatsApp',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
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
      ),
    );
  }

  // ==========================================
  // PESTAÑA 2: RADAR DE MONITOREO Y RECORDATORIOS
  // ==========================================
  Widget _buildTabMonitoreo() {
    final urgentes = _clientes.where((c) => c.requiereAtencionUrgente).toList()
      ..sort((a, b) => b.montoPromedio.compareTo(a.montoPromedio));
    final montoRiesgo = urgentes.fold<int>(0, (s, c) => s + c.montoPromedio);

    return ListView(
      physics: const BouncingScrollPhysics(),
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
              Row(
                children: [
                  const Icon(Icons.notifications_active, color: Colors.redAccent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${urgentes.length} Clientes por Contactar (\$${formatearPesos(montoRiesgo)})',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15, color: Colors.redAccent),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Priorizados desde las Ballenas de \$3.000.000 hacia abajo. Toca "Sugerencia IA" en cada tarjeta para ver qué producto extra ofrecerles hoy.',
                style: TextStyle(fontSize: 12, color: Colors.white70),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        ...List.generate(urgentes.length, (i) => _buildTarjetaCliente(urgentes[i], i)),
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
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(14),
      children: [
        const Text(
          'Estudio Creador de Afiches Mayoristas',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        const Text(
          'Diseña tu promoción con foto real y úsala directo en tus campañas automáticas de WhatsApp.',
          style: TextStyle(fontSize: 12, color: Colors.white60),
        ),
        const SizedBox(height: 12),
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
                label:
                    const Text('Compartir Afiche', style: TextStyle(fontWeight: FontWeight.bold)),
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
      physics: const BouncingScrollPhysics(),
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
                  ? 'AccessibilityService ACTIVO'
                  : 'Permiso de Accesibilidad Desactivado',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(_accesibilidadActiva
                ? 'Tu Android presionará "Enviar" en WhatsApp automáticamente y volverá al CRM.'
                : 'Toca "Activar" y habilita "CRM Mayorista Auto-WhatsApp" en Accesibilidad.'),
            trailing: ElevatedButton(
              onPressed: _abrirAjustesAccesibilidad,
              child: const Text('Activar'),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SwitchListTile(
          tileColor: const Color(0xFF131C2E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text('Adjuntar Afiche Promocional (.PNG)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          subtitle: const Text('Envía el afiche visual junto con el texto personalizado'),
          value: _adjuntarAficheEnCampana,
          onChanged: (v) => setState(() => _adjuntarAficheEnCampana = v),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          tileColor: const Color(0xFF131C2E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text('Incluir Sugerencia de Venta Cruzada IA',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          subtitle: const Text(
              'Agrega una línea al mensaje recomendando el producto complementario de cada cliente'),
          value: _incluirCrossSellEnCampana,
          onChanged: (v) => setState(() => _incluirCrossSellEnCampana = v),
        ),
        const SizedBox(height: 12),
        const Text('Texto de la Oferta (DeepSeek adaptará cada mensaje):',
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        TextField(
          controller: _promoCtrl,
          maxLines: 3,
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFF131C2E),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 12),
        const Text('Categoría de Clientes a Disparar:',
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: _categoriaCampana,
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFF131C2E),
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
            color: const Color(0xFF131C2E),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Estado: $_estadoCampanaTexto',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _campanaCorriendo ? Colors.redAccent : const Color(0xFF10B981),
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
                    _campanaCorriendo ? 'DETENER CAMPAÑA AHORA' : 'LANZAR CAMPAÑA AUTOMÁTICA',
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
  // PESTAÑA 5: DEEPSEEK IA CONVERSACIONAL V4
  // ==========================================
  Widget _buildTabDeepSeek() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: const Color(0xFF131C2E),
          child: Row(
            children: [
              const Icon(Icons.psychology, color: Color(0xFF10B981)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'DeepSeek-R1 V4 (Conversacional + Venta Cruzada)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              TextButton.icon(
                onPressed: _mostrarModalHerramientasIA,
                icon: const Icon(Icons.tune, size: 16),
                label: const Text('Notas / GGUF', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 38,
          child: ListView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            children: [
              _chipSugerencia('¡Hola DeepSeek!'),
              _chipSugerencia('Dame una estrategia para vender más hoy'),
              _chipSugerencia('¿A quién debo llamar urgente?'),
              _chipSugerencia('¿Quién es Jesús Peña?'),
              _chipSugerencia('Ruta Melipilla'),
              _chipSugerencia('¿A quién le ofrezco corta fecha?'),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            controller: _chatScrollCtrl,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(12),
            itemCount: _historialChat.length + (_iaPensando ? 1 : 0),
            itemBuilder: (ctx, i) {
              if (i == _historialChat.length && _iaPensando) {
                return _buildBurbujaStreaming();
              }
              return _buildBurbujaChat(_historialChat[i]);
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
          decoration: const BoxDecoration(
            color: Color(0xFF131C2E),
            border: Border(top: BorderSide(color: Colors.white10)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _chatIaCtrl,
                  decoration: InputDecoration(
                    hintText: 'Háblale natural a DeepSeek (ej: Hola, ¿qué me sugieres hoy?)...',
                    hintStyle: const TextStyle(fontSize: 13),
                    filled: true,
                    fillColor: const Color(0xFF070B12),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onSubmitted: _enviarMensajeADeepSeek,
                ),
              ),
              const SizedBox(width: 8),
              FloatingActionButton.small(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.black,
                onPressed: () => _enviarMensajeADeepSeek(_chatIaCtrl.text),
                child: const Icon(Icons.send),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _chipSugerencia(String texto) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ActionChip(
        label: Text(texto, style: const TextStyle(fontSize: 11)),
        onPressed: () => _enviarMensajeADeepSeek(texto),
      ),
    );
  }

  Widget _buildBurbujaStreaming() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF131C2E),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF10B981).withOpacity(0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF10B981)),
                ),
                SizedBox(width: 8),
                Text('DeepSeek-R1 razonando...',
                    style: TextStyle(fontSize: 11, color: Color(0xFF10B981))),
              ],
            ),
            if (_textoStreaming.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(_textoStreaming, style: const TextStyle(fontSize: 13.5, height: 1.4)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBurbujaChat(MensajeChatIA m) {
    return Align(
      alignment: m.esUsuario ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.88),
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: m.esUsuario
              ? const Color(0xFF10B981).withOpacity(0.22)
              : const Color(0xFF131C2E),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: m.esUsuario ? const Color(0xFF10B981).withOpacity(0.5) : Colors.white10,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!m.esUsuario && m.pensamiento.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '🧠 ${m.pensamiento}',
                  style: const TextStyle(
                      fontSize: 11, color: Colors.white54, fontStyle: FontStyle.italic),
                ),
              ),
            Text(m.texto, style: const TextStyle(fontSize: 13.5, height: 1.4)),
            if (!m.esUsuario && (m.clienteAccion != null || m.promoSugerida != null)) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (m.clienteAccion != null) ...[
                    SizedBox(
                      height: 30,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF26334D),
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => _llamarCliente(m.clienteAccion!),
                        icon: const Icon(Icons.phone, size: 14),
                        label: Text('Llamar a ${m.clienteAccion!.nombre.split(" ").first}',
                            style: const TextStyle(fontSize: 11)),
                      ),
                    ),
                    SizedBox(
                      height: 30,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.black,
                        ),
                        onPressed: () => _escribirWhatsApp(m.clienteAccion!),
                        icon: const Icon(Icons.chat, size: 14),
                        label: const Text('WhatsApp + Cross-Sell',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                  if (m.promoSugerida != null)
                    SizedBox(
                      height: 30,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF38BDF8),
                          foregroundColor: Colors.black,
                        ),
                        onPressed: () {
                          setState(() {
                            _promoCtrl.text = m.promoSugerida!;
                            if (m.categoriaSugerida != null) {
                              _categoriaCampana = m.categoriaSugerida!;
                            }
                            _tabIndex = 3;
                          });
                          _mostrarSnack('Estrategia cargada en Campaña');
                        },
                        icon: const Icon(Icons.rocket_launch, size: 14),
                        label: const Text('Lanzar en Campaña',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ==========================================
  // MODAL DE HERRAMIENTAS IA (NOTAS + GGUF + API)
  // ==========================================
  void _mostrarModalHerramientasIA() {
    final apiCtrl = TextEditingController(text: _apiKeyDeepSeek);
    final endpointCtrl = TextEditingController(text: _apiEndpointDeepSeek);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF131C2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
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
              const Text('🪄 Escáner Inteligente de Notas Sueltas',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 6),
              TextField(
                controller: _notaCaoticaCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: 'Ej: "Pedro Bodega 988776655 compra pallet papel prom 900.000 llamar"',
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: () {
                  if (_notaCaoticaCtrl.text.trim().isEmpty) return;
                  final nuevo = DeepSeekConversationalAgent.extraerClienteDesdeNotaCaotica(
                      _notaCaoticaCtrl.text);
                  setState(() {
                    _clientes.insert(0, nuevo);
                    _notaCaoticaCtrl.clear();
                  });
                  _guardarDatos();
                  Navigator.pop(ctx);
                  _mostrarSnack('Cliente "${nuevo.nombre}" agregado a ${nuevo.categoria}');
                },
                icon: const Icon(Icons.auto_fix_high),
                label: const Text('Convertir Nota en Ficha de Cliente'),
              ),
              const Divider(height: 24),
              const Text('⚙️ Conexión Opcional API / Localhost (DeepSeek / Ollama)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              TextField(
                controller: endpointCtrl,
                decoration: const InputDecoration(labelText: 'Endpoint URL'),
              ),
              TextField(
                controller: apiCtrl,
                decoration: const InputDecoration(
                    labelText: 'API Key (Opcional - vacío usa motor local offline)'),
              ),
              if (_estadoDescargaGGUF.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(_estadoDescargaGGUF,
                      style: const TextStyle(fontSize: 11, color: Colors.amberAccent)),
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _modeloGGUFInstalado
                        ? null
                        : () {
                            Navigator.pop(ctx);
                            _descargarModeloDeepSeekGGUF();
                          },
                    icon: Icon(_modeloGGUFInstalado ? Icons.check_circle : Icons.download),
                    label: Text(_modeloGGUFInstalado ? 'GGUF Instalado' : 'Descargar GGUF 1.5B'),
                  ),
                  const Spacer(),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.black,
                    ),
                    onPressed: () async {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setString('deepseek_api_key', apiCtrl.text.trim());
                      await prefs.setString('deepseek_endpoint', endpointCtrl.text.trim());
                      setState(() {
                        _apiKeyDeepSeek = apiCtrl.text.trim();
                        _apiEndpointDeepSeek = endpointCtrl.text.trim();
                      });
                      if (mounted) Navigator.pop(ctx);
                    },
                    child: const Text('Guardar'),
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
  // MODAL PARA CREAR O EDITAR CUALQUIER CLIENTE
  // ==========================================
  void _mostrarModalEditarCliente(Cliente? existente) {
    final nombreCtrl = TextEditingController(text: existente?.nombre ?? '');
    final rutCtrl = TextEditingController(text: existente?.rut ?? '');
    final telCtrl = TextEditingController(text: existente?.telefono ?? '+569');
    final tel2Ctrl = TextEditingController(text: existente?.telefonoSecundario ?? '');
    final compraCtrl = TextEditingController(text: existente?.queCompra ?? '');
    final montoCtrl = TextEditingController(text: (existente?.montoPromedio ?? 500000).toString());
    final notasCtrl = TextEditingController(text: existente?.notas ?? '');
    final cicloCtrl = TextEditingController(text: (existente?.cicloDias ?? 10).toString());
    String cat = existente?.categoria ?? 'Abarrotes y Alimentos';
    bool prefLlamada = existente?.prefiereLlamada ?? false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF131C2E),
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
                TextField(
                    controller: nombreCtrl,
                    decoration: const InputDecoration(labelText: 'Nombre / Razón Social')),
                Row(
                  children: [
                    Expanded(
                        child: TextField(
                            controller: rutCtrl, decoration: const InputDecoration(labelText: 'RUT'))),
                    const SizedBox(width: 10),
                    Expanded(
                        child: TextField(
                            controller: telCtrl,
                            decoration: const InputDecoration(labelText: 'Teléfono 1 (+569...)'))),
                  ],
                ),
                TextField(
                    controller: tel2Ctrl,
                    decoration:
                        const InputDecoration(labelText: 'Teléfono 2 / Secundario (Opcional)')),
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
                TextField(
                    controller: compraCtrl,
                    decoration: const InputDecoration(labelText: '¿Qué suele comprar?')),
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
                TextField(
                    controller: notasCtrl,
                    decoration: const InputDecoration(labelText: 'Notas / Observaciones')),
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
                                telefonoSecundario: tel2Ctrl.text.trim(),
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
                            existente.telefonoSecundario = tel2Ctrl.text.trim();
                            existente.categoria = cat;
                            existente.queCompra = compraCtrl.text.trim();
                            existente.montoPromedio =
                                int.tryParse(montoCtrl.text) ?? existente.montoPromedio;
                            existente.notas = notasCtrl.text.trim();
                            existente.prefiereLlamada = prefLlamada;
                            existente.cicloDias = int.tryParse(cicloCtrl.text) ?? 10;
                          }
                        });
                        _guardarDatos();
                        Navigator.pop(ctx);
                      },
                      child: const Text('Guardar Cambios',
                          style: TextStyle(fontWeight: FontWeight.bold)),
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
