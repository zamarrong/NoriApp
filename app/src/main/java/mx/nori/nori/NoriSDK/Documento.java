package mx.nori.nori.NoriSDK;

import com.google.gson.annotations.Expose;
import com.google.gson.annotations.SerializedName;
import com.j256.ormlite.dao.Dao;
import com.j256.ormlite.field.DatabaseField;
import com.j256.ormlite.table.DatabaseTable;

import java.util.ArrayList;
import java.util.Date;
import java.util.List;

import mx.nori.nori.Functions;
import mx.nori.nori.MainActivity;
import retrofit2.Call;
import retrofit2.Callback;
import retrofit2.Response;

@DatabaseTable(tableName = "documentos")
public class Documento {
    @DatabaseField(columnName = "id", generatedId = true, unique = true)
    @SerializedName("id")
    @Expose
    private Integer id;

    @DatabaseField(columnName = "serie_id")
    @SerializedName("serie_id")
    @Expose
    private Integer serie_id;

    @DatabaseField(columnName = "condicion_pago_id")
    @SerializedName("condicion_pago_id")
    @Expose
    private Integer condicion_pago_id;


    @DatabaseField(columnName = "estacion_id")
    @SerializedName("estacion_id")
    @Expose
    private Integer estacion_id;


    @DatabaseField(columnName = "moneda_id")
    @SerializedName("moneda_id")
    @Expose
    private Integer moneda_id;


    @DatabaseField(columnName = "tipo_cambio")
    @SerializedName("tipo_cambio")
    @Expose
    private Double tipo_cambio;

    @DatabaseField(columnName = "metodo_pago_id")
    @SerializedName("metodo_pago_id")
    @Expose
    private Integer metodo_pago_id;

    @DatabaseField(columnName = "cuenta_pago")
    @SerializedName("cuenta_pago")
    @Expose
    private String cuenta_pago;

    @DatabaseField(columnName = "vendedor_id")
    @SerializedName("vendedor_id")
    @Expose
    private Integer vendedor_id;

    @DatabaseField(columnName = "socio_id")
    @SerializedName("socio_id")
    @Expose
    private Integer socio_id;

    @DatabaseField(columnName = "persona_contacto_id")
    @SerializedName("persona_contacto_id")
    @Expose
    private Integer persona_contacto_id;

    @DatabaseField(columnName = "codigo_sn")
    @SerializedName("codigo_sn")
    @Expose
    private String codigo_sn;

    @DatabaseField(columnName = "direccion_facturacion_id")
    @SerializedName("direccion_facturacion_id")
    @Expose
    private Integer direccion_facturacion_id;

    @DatabaseField(columnName = "direccion_envio_id")
    @SerializedName("direccion_envio_id")
    @Expose
    private Integer direccion_envio_id;

    @DatabaseField(columnName = "clase_expedicion_id")
    @SerializedName("clase_expedicion_id")
    @Expose
    private Integer clase_expedicion_id;

    @DatabaseField(columnName = "chofer_id")
    @SerializedName("chofer_id")
    @Expose
    private Integer chofer_id;

    @DatabaseField(columnName = "vehiculo_id")
    @SerializedName("vehiculo_id")
    @Expose
    private Integer vehiculo_id;

    @DatabaseField(columnName = "ruta_id")
    @SerializedName("ruta_id")
    @Expose
    private Integer ruta_id;

    @DatabaseField(columnName = "supervisor_id")
    @SerializedName("supervisor_id")
    @Expose
    private Integer supervisor_id;

    @DatabaseField(columnName = "causalidad_id")
    @SerializedName("causalidad_id")
    @Expose
    private Integer causalidad_id;

    @DatabaseField(columnName = "canal_id")
    @SerializedName("canal_id")
    @Expose
    private Integer canal_id;

    @DatabaseField(columnName = "lista_precio_id")
    @SerializedName("lista_precio_id")
    @Expose
    private Integer lista_precio_id;

    @DatabaseField(columnName = "almacen_id")
    @SerializedName("almacen_id")
    @Expose
    private Integer almacen_id;

    @DatabaseField(columnName = "almacen_destino_id")
    @SerializedName("almacen_destino_id")
    @Expose
    private Integer almacen_destino_id;

    @DatabaseField(columnName = "tipo")
    @SerializedName("tipo")
    @Expose
    private Character tipo;

    @DatabaseField(columnName = "clase")
    @SerializedName("clase")
    @Expose
    private String clase;

    @DatabaseField(columnName = "estado")
    @SerializedName("estado")
    @Expose
    private Character estado;

    @DatabaseField(columnName = "numero_documento")
    @SerializedName("numero_documento")
    @Expose
    private Integer numero_documento;

    @DatabaseField(columnName = "subtotal")
    @SerializedName("subtotal")
    @Expose
    private Double subtotal;

    @DatabaseField(columnName = "porcentaje_descuento")
    @SerializedName("porcentaje_descuento")
    @Expose
    private Double porcentaje_descuento;

    @DatabaseField(columnName = "descuento")
    @SerializedName("descuento")
    @Expose
    private Double descuento;

    @DatabaseField(columnName = "impuesto")
    @SerializedName("impuesto")
    @Expose
    private Double impuesto;

    @DatabaseField(columnName = "total")
    @SerializedName("total")
    @Expose
    private Double total;

    @DatabaseField(columnName = "importe_aplicado")
    @SerializedName("importe_aplicado")
    @Expose
    private Double importe_aplicado;

    @DatabaseField(columnName = "orden_compra")
    @SerializedName("orden_compra")
    @Expose
    private String orden_compra;

    @DatabaseField(columnName = "referencia")
    @SerializedName("referencia")
    @Expose
    private String referencia;

    @DatabaseField(columnName = "comentario")
    @SerializedName("comentario")
    @Expose
    private String comentario;

    @DatabaseField(columnName = "servicio")
    @SerializedName("servicio")
    @Expose
    private Boolean servicio;

    @DatabaseField(columnName = "reserva")
    @SerializedName("reserva")
    @Expose
    private Boolean reserva;

    @DatabaseField(columnName = "impreso")
    @SerializedName("impreso")
    @Expose
    private Boolean impreso;

    @DatabaseField(columnName = "cancelado")
    @SerializedName("cancelado")
    @Expose
    private Boolean cancelado;

    @DatabaseField(columnName = "foraneo")
    @SerializedName("foraneo")
    @Expose
    private Boolean foraneo;

    @DatabaseField(columnName = "uso_principal")
    @SerializedName("uso_principal")
    @Expose
    private String uso_principal;

    @DatabaseField(columnName = "identificador_externo")
    @SerializedName("identificador_externo")
    @Expose
    private Integer identificador_externo;

    @DatabaseField(columnName = "numero_documento_externo")
    @SerializedName("numero_documento_externo")
    @Expose
    private Integer numero_documento_externo;

    @DatabaseField(columnName = "fecha_contabilizacion")
    @SerializedName("fecha_contabilizacion")
    @Expose
    private Date fecha_contabilizacion;

    @DatabaseField(columnName = "fecha_vencimiento")
    @SerializedName("fecha_vencimiento")
    @Expose
    private Date fecha_vencimiento;

    @DatabaseField(columnName = "fecha_documento")
    @SerializedName("fecha_documento")
    @Expose
    private Date fecha_documento;

    @DatabaseField(columnName = "usuario_creacion_id")
    @SerializedName("usuario_creacion_id")
    @Expose
    private Integer usuario_creacion_id;

    @DatabaseField(columnName = "fecha_creacion")
    private transient Date fecha_creacion;

    @DatabaseField(columnName = "usuario_actualizacion_id")
    @SerializedName("usuario_actualizacion_id")
    @Expose
    private Integer usuario_actualizacion_id;

    @DatabaseField(columnName = "fecha_actualizacion")
    private transient Date fecha_actualizacion;

    //Interno
    private List<Partida> partidas;
    private List<Flujo> flujo;
    private Integer numero_partidas;
    private Double cantidad_empaque;
    private Double cantidad_partidas;

    public static Dao Documentos() {
        try {
            return MainActivity.db.Documentos();
        } catch (Exception ex) {
            return null;
        }
    }

    public Documento() {
        id = numero_documento = identificador_externo = numero_documento_externo = socio_id = 0;
        estacion_id = Global.getEstacion_id();
        moneda_id = Global.getConfiguracion().getMoneda_id();
        lista_precio_id = Global.getConfiguracion().getLista_precio_id();
        tipo_cambio = 1.0;
        vendedor_id = Global.getUsuario().getVendedor_id();
        clase_expedicion_id = Global.getUsuario().getClase_expedicion_id();
        chofer_id = vehiculo_id = ruta_id = supervisor_id = causalidad_id = canal_id = 0;
        almacen_id = almacen_destino_id = 0;
        tipo = Tipo.ObtenerPredeterminado();
        clase = Clase.ObtenerPredeterminado().clase;
        estado = Estado.ObtenerPredeterminado();
        referencia = "";
        comentario = "";
        servicio = false;
        reserva = false;
        impreso = false;
        cancelado = false;
        foraneo = true;
        uso_principal = "G01";
        fecha_contabilizacion = Functions.getCurrentDateTime();
        fecha_vencimiento = Functions.getCurrentDateTime();
        fecha_documento = Functions.getCurrentDateTime();
        usuario_creacion_id = Global.getUsuario().getId();
        fecha_creacion = Functions.getCurrentDateTime();
        usuario_actualizacion_id = Global.getUsuario().getId();
        fecha_actualizacion = Functions.getCurrentDateTime();
        //Interno
        partidas = new ArrayList<>();
        flujo = new ArrayList<>();
    }

    public void AgregarPartidas() {
        try {
            List<Articulo.Inventario> inventarios = Articulo.Inventario.Inventarios().queryBuilder().where().eq("almacen_id", Global.getUsuario().getAlmacen_id()).and().rawComparison("stock", ">", 0).query();
            for (Articulo.Inventario inventario : inventarios) {
                Articulo articulo = Articulo.Obtener(inventario.getArticulo_id());

                if (articulo != null) {
                    AgregarPartida("0*" + articulo.getSku(), 0.0);
                }
            }
        }
        catch (Exception ex) {
            Global.setError(ex);
        }
    }

    public Boolean Agregar() {
        try {
            if (id != 0) {
                Global.setError(new Exception("El documento ya cuenta con un identificador."));
                return false;
            }

            if (socio_id == 0) {
                Global.setError(new Exception("Aún no se ha establecido un socio."));
                return false;
            }

            if (moneda_id == 0) {
                Global.setError(new Exception("Aún no se ha especificado una moneda."));
                return false;
            }

            if (condicion_pago_id == 0) {
                Global.setError(new Exception("Aún no se ha especificado una condición de pago."));
                return false;
            }

            if (metodo_pago_id == 0) {
                Global.setError(new Exception("Aún no se ha especificado un método de pago."));
                return false;
            }

            if (lista_precio_id == 0) {
                Global.setError(new Exception("Aún no se ha establecido una lista de precio."));
                return false;
            }

            if (vendedor_id == 0) {
                Global.setError(new Exception("Aún no se ha establecido un vendedor."));
                return false;
            }

            if (partidas.size() <= 0) {
                Global.setError(new Exception("El documento no contiene partidas."));
                return false;
            }

            /*if (direccion_envio_id == 0 || direccion_facturacion_id == 0) {
                Global.setError(new Exception("Aún no se ha establecido la dirección de facturación y/o envío."));
                return false;
            }*/

            Ruta ruta = Global.getUsuario().ObtenerRuta();
            if (ruta != null) {
                ruta_id = ruta.getId();
            }

            if (reserva == true && clase != "FA") {
                reserva = false;
            }

            if (id == 0) {
                CondicionesPago condicion_pago = CondicionesPago.Obtener(condicion_pago_id);
                if (condicion_pago != null) {
                    fecha_vencimiento = Functions.addDays(fecha_vencimiento, condicion_pago.getDias_extra());
                }
            }

            if (total == 0) {
                CalcularTotal();
            }

            if (total == 0) {
                Global.setError(new Exception("No es posible guardar un documento con total igual a cero."));
                return false;
            }

            if (importe_aplicado > total) {
                importe_aplicado = total;
            }

            Serie serie = (serie_id == null || serie_id == 0) ? Serie.ObtenerPredeterminado(clase) : Serie.Obtener(serie_id);
            if (serie == null) {
                Global.setError(new Exception("Aún no se ha establecido una serie predeterminada para esta clase de documento."));
                return false;
            } else {
                if (!serie.getClase().equals(clase)) {
                    Global.setError(new Exception("La clase de documento de la serie indicada y la del documento no coinciden."));
                    return false;
                }
            }

            serie_id = serie.getId();

            if (numero_documento == 0) {
                numero_documento = serie.getSiguiente();
            }

            Documentos().create(this);

            serie.EstablecerSiguiente();

            for(Partida partida : partidas) {
                partida.cantidad_pendiente = partida.cantidad;
                partida.documento_id = id;
                if (partida.cantidad > 0) {
                    partida.Agregar();
                }
            }

            for(Flujo flujo : flujo) {
                flujo.setDocumento_id(id);
                if (flujo.getImporte() > 0) {
                    flujo.Agregar();
                }
            }

            AfectarInventario(false, ObtenerPartidas());

            return true;
        } catch (Exception ex) {
            Global.setError(ex);
            return false;
        }
    }

    public static Documento Obtener(Integer id) {
        try {
            Documento documento = (Documento) Documentos().queryForId(id);

            documento.partidas = documento.ObtenerPartidas();
            documento.flujo = documento.ObtenerFlujo();

            documento.CalcularTotal();

            return documento;
        } catch (Exception ex) {
            Global.setError(ex);
            return null;
        }
    }

    public List<Partida> ObtenerPartidas() {
        try {
            return (List<Partida>) Partida.Partidas().queryBuilder().where().eq("documento_id", id).query();
        } catch (Exception ex) {
            Global.setError(ex);
            return null;
        }
    }

    public List<Flujo> ObtenerFlujo() {
        try {
            return (List<Flujo>) Flujo.Flujo().queryBuilder().where().eq("documento_id", id).query();
        } catch (Exception ex) {
            Global.setError(ex);
            return null;
        }
    }

    public static List<Documento> Listar() {
        try {
            return (List<Documento>) Documentos().queryForAll();
        } catch (Exception ex) {
            Global.setError(ex);
            return null;
        }
    }

    public static List<Documento> ListarPorClase(String clase) {
        try {
            return (List<Documento>) Documentos().queryBuilder().orderBy("id", false).where().eq("clase", clase).query();
        } catch (Exception ex) {
            Global.setError(ex);
            return null;
        }
    }

    public Boolean Cancelar() {
        try {
            if (identificador_externo != 0) {
                Global.setError(new Exception("El documento ya cuenta con un identificador y no puede ser cancelado."));
                return false;
            }

            if (estado.equals('C')) {
                Global.setError(new Exception("Este documento ya ha sido cerrado y no puede modificarse."));
                return false;
            }

            if (cancelado) {
                Global.setError(new Exception("Este documento ha sido cancelado y no puede modificarse."));
                return false;
            }

            AfectarInventario(true, ObtenerPartidas());

            cancelado = true;
            estado = 'C';
            usuario_actualizacion_id = Global.getUsuario().getId();
            fecha_actualizacion = Functions.getCurrentDateTime();

            Documentos().update(this);

            return true;
        } catch (Exception ex) {
            Global.setError(ex);
            return false;
        }
    }

    public Boolean Actualizar() {
        try {
            usuario_actualizacion_id = Global.getUsuario().getId();
            fecha_actualizacion = Functions.getCurrentDateTime();
            Documentos().update(this);
            return true;
        } catch (Exception ex) {
            Global.setError(ex);
            return false;
        }
    }

    public static void Sincronizar() {
        try {
            List<Documento> documentos = Documentos().queryBuilder().where().eq("identificador_externo", 0).and().eq("cancelado", false).query();

            for(Documento documento : documentos) {
                try {
                    documento = Documento.Obtener(documento.id);
                    Documento documento_agregado = MainActivity.api.documento(documento).execute().body();

                    documento.identificador_externo = documento_agregado.getId();
                    documento.numero_documento_externo = documento_agregado.getNumero_documento();

                    documento.Actualizar();
                } catch (Exception ex) {
                    continue;
                }
            }
        } catch (Exception ex) {
            Global.setError(ex);
        } finally {
            Global.setSincronizando(false);
        }
    }

    //Funciones
    public Boolean EstablecerSocio(Socio socio) {
        try {
            socio_id = 0;
            if (socio.getActivo()) {
                if (socio.getTipo().equals('P') && tipo.equals('V'))
                {
                    Global.setError(new Exception("El socio debe ser del tipo cliente."));
                    return false;
                }
                else if (socio.getTipo().equals('C') && tipo.equals('C'))
                {
                    Global.setError(new Exception("El socio debe ser del tipo proveedor."));
                    return false;
                }

                socio_id = socio.getId();
                codigo_sn = socio.getCodigo();
                persona_contacto_id = socio.getPersona_contacto_id();
                vendedor_id = (socio.getVendedor_id() == 0) ? Global.getUsuario().getVendedor_id() : socio.getVendedor_id();
                metodo_pago_id = socio.getMetodo_pago_id();
                if (metodo_pago_id == 0) {
                    metodo_pago_id = Global.getConfiguracion().getMetodo_pago_id();
                }
                condicion_pago_id = socio.getCondicion_pago_id();
                if (lista_precio_id != socio.getLista_precio_id())
                {
                    lista_precio_id = socio.getLista_precio_id();
                    RecalcularTotalPartidas(true);
                }
                direccion_facturacion_id = socio.getDireccion_facturacion_id();
                direccion_envio_id = socio.getDireccion_envio_id();
                porcentaje_descuento = socio.getPorcentaje_descuento();
                cuenta_pago = socio.getCuenta_pago();
                uso_principal = socio.getUso_principal();

                return true;
            } else {
                Global.setError(new Exception("El socio esta inactivo."));
                return false;
            }
        } catch (Exception ex) {
            Global.setError(ex);
            return  false;
        }
    }

    public void RecalcularTotalPartidas(boolean actualizar_precios) {
        if (actualizar_precios) {
            for (Partida partida : partidas) {
                partida.ObtenerPrecio(socio_id, lista_precio_id);
            }
        }

        for (Partida partida : partidas) {
            partida.CalcularTotal();
        }

        CalcularTotal();
    }

    public void CalcularTotal() {
        try {
            numero_partidas = partidas.size();
            cantidad_partidas = 0.0;
            cantidad_empaque = 0.0;
            subtotal = 0.0;
            descuento = 0.0;
            impuesto = 0.0;
            total = 0.0;
            importe_aplicado = 0.0;

            if (partidas.size() > 0) {
                Double total_partidas = TotalPartidas();

                for (Partida partida : partidas) {
                    if (partida.tipo_cambio != (1 / tipo_cambio)) {
                        partida.ModificarTipoCambio(partida.ObtenerTipoCambio(moneda_id, tipo_cambio) / tipo_cambio);
                    }

                    cantidad_partidas += partida.cantidad;
                    cantidad_empaque += partida.cantidad_empaque;
                    subtotal += partida.subtotal;

                    Descuento:
                    {
                        if (porcentaje_descuento > 0) {
                            descuento = ((porcentaje_descuento / 100) * subtotal);
                        } else if (descuento > 0) {
                            porcentaje_descuento = (descuento / total_partidas) *100;
                            break Descuento;
                        }
                    }
                }

                Double impuesto_partidas = ImpuestoPartidas();
                Double descuento_impuesto = (porcentaje_descuento / 100) * impuesto_partidas;

                impuesto = impuesto_partidas - descuento_impuesto;

                total = (subtotal - descuento) + impuesto;

                for (Flujo flujo : flujo) {
                    importe_aplicado += (flujo.getTipo_cambio() * flujo.getImporte());
                }
            }
        } catch (Exception ex) {
            Global.setError(ex);
        }
    }

    private Double TotalPartidas() {
        try {
            Double total = 0.0;

            for (Partida partida : partidas) {
                total += partida.total;
            }

            return total;
        } catch (Exception ex) {
            Global.setError(ex);
            return 0.0;
        }
    }

    private Double ImpuestoPartidas() {
        try {
            Double impuesto = 0.0;

            for (Partida partida : partidas) {
                impuesto += (partida.cantidad * partida.impuesto);
            }

            return impuesto;
        } catch (Exception ex) {
            Global.setError(ex);
            return 0.0;
        }
    }

    public Boolean AgregarPartida(String q, Double precio)
    {
        try {
            Partida partida = new Partida();

            if (q.contains("*")) {
                partida.cantidad = Double.parseDouble(q.split("\\*")[0]);
                q = q.split("\\*")[1];
            }

            if (partida.cantidad < 0) {
                Global.setError(new Exception("No es posible agregar partidas con cantidad < 0."));
                return false;
            }

            Articulo articulo = (Articulo) Articulo.Articulos().queryBuilder().where().eq("sku", q).or().eq("codigo_barras", q).or().eq("id_adicional", q).and().eq("activo", true).queryForFirst();

            if (articulo == null) {
                Articulo.CodigoBarras codigo_barras = (Articulo.CodigoBarras) Articulo.CodigoBarras.CodigosBarras().queryBuilder().where().eq("codigo", q).queryForFirst();

                if (codigo_barras == null) {
                    Global.setError(new Exception("Artículo no encontrado."));
                    return false;
                }

                articulo = (Articulo) Articulo.Articulos().queryBuilder().where().eq("id", codigo_barras.getArticulo_id()).and().eq("activo", true).queryForFirst();

                if (articulo == null) {
                    Global.setError(new Exception("Artículo no encontrado, inactivo."));
                    return false;
                }

                partida.unidad_medida_id = codigo_barras.getUnidad_medida_id();
                partida.codigo_barras = codigo_barras.getCodigo();
            } else {
                Articulo.CodigoBarras codigo_barras = (Articulo.CodigoBarras) Articulo.CodigoBarras.CodigosBarras().queryBuilder().where().eq("codigo", articulo.getCodigo_barras()).queryForFirst();

                if (codigo_barras != null) {
                    partida.unidad_medida_id = codigo_barras.getUnidad_medida_id();
                    partida.codigo_barras = codigo_barras.getCodigo();
                }
            }

            if (tipo.equals('C') && !articulo.getCompra()) {
                Global.setError(new Exception("El artículo no se puede comprar."));
                return false;
            }

            if (tipo.equals('V') && !articulo.getVenta()) {
                Global.setError(new Exception("El artículo no se puede vender."));
                return false;
            }

            partida.articulo_id = articulo.getId();
            if (partida.unidad_medida_id == 0) {
                partida.unidad_medida_id = articulo.getUnidad_medida_id();
            }

            Boolean existente = false;

            if (partidas.size() > 0) {
                Integer i_partida = ObtenerPartidaExistente(partida.articulo_id);
                if (i_partida != -1) {
                    Double cantidad = partida.cantidad;
                    partida = partidas.get(i_partida);
                    partida.fecha_lectura = Functions.getCurrentDateTime();
                    partida.cantidad += cantidad;

                    existente = true;
                }
            }

            partida.sku = articulo.getSku();
            partida.nombre = articulo.getNombre();
            if (partida.codigo_barras == null) {
                partida.codigo_barras = articulo.getCodigo_barras();

            }
            partida.cantidad_paquete = articulo.getCantidad_paquete();
            partida.norma_reparto = Global.getUsuario().getNorma_reparto();

            //if (partida.id == 0) Descuento

            if (!existente) {
                if (articulo.getAlmacenable()) {
                    if (clase.equals("ST")) {
                        if (almacen_id != 0) {
                            partida.almacen_id = almacen_id;
                        } else {
                            partida.almacen_id = articulo.getAlmacen_id();
                        }

                        if (almacen_destino_id != 0) {
                            partida.almacen_destino_id = almacen_destino_id;
                        } else {
                            partida.almacen_destino_id = Global.getUsuario().getAlmacen_id();
                        }
                    } else {
                        if (Global.getUsuario().getAlmacen_id() == 0) {
                            partida.almacen_id = articulo.getAlmacen_id();
                        } else {
                            partida.almacen_id = Global.getUsuario().getAlmacen_id();
                        }
                    }

                    if (partida.almacen_id == 0) {
                        Global.setError(new Exception("Aún no se ha establecido un almacén para esta partida."));
                        return false;
                    }

                    Almacen almacen = Almacen.Obtener(partida.almacen_id);

                    if (Global.getUsuario().getUbicacion_id() == 0) {
                        partida.ubicacion_id = almacen.getUbicacion_id();
                    } else {
                        partida.ubicacion_id = Global.getUsuario().getUbicacion_id();
                    }

                    if (almacen.getUbicaciones() && partida.ubicacion_id == 0) {
                        Global.setError(new Exception("Aún no se ha establecido una ubicación para esta partida."));
                        return false;
                    }

                    try {
                        if (Articulo.Inventario.Inventarios().queryBuilder().where().eq("almacen_id", partida.almacen_id).and().eq("articulo_id", partida.articulo_id).and().eq("activo", false).countOf() > 0) {
                            Global.setError(new Exception("El artículo esta inactivo en este almacén."));
                            return false;
                        }
                    } catch (Exception ex) {
                        Global.setError(new Exception("El artículo no esta disponible en este almacén."));
                        return false;
                    }

                    if (partidas.size() > 0) {
                        if (clase.equals("ST") || clase.equals("TS")) {
                            if (partida.almacen_destino_id == 0) {
                                partida.almacen_destino_id = partidas.get(partidas.size() - 1).getAlmacen_destino_id();
                            }
                        }
                    }

                    partida.ObtenerStock();
                }

                if (socio_id == 0 || lista_precio_id == 0) {
                    Global.setError(new Exception("Aún no se ha establecido el socio y/o la lista de precio."));
                    return false;
                }

                if (precio == 0) {
                    if (!partida.ObtenerPrecio(socio_id, lista_precio_id)) {
                        Global.setError(new Exception("No se encontró un precio para este artículo."));
                        return false;
                    }
                } else {
                    partida.precio = precio;
                    Impuesto impuesto = Articulo.ObtenerImpuesto(partida.articulo_id, socio_id);

                    if (impuesto.getId() != 0) {
                        partida.impuesto_id = impuesto.getId();
                        partida.porcentaje_impuesto = impuesto.getPorcentaje();
                    }
                }

                if (partida.moneda_id == 0) {
                    partida.moneda_id = Global.getConfiguracion().getMoneda_id();
                }

                partidas.add(partida);
            }

            partida.CalcularCantidadPendiente(id);

            return true;
        } catch (Exception ex) {
            Global.setError(ex);
            return false;
        }
    }

    private void AfectarInventario(Boolean cancelacion, List<Partida> partidas) {
        try {
            if (partidas == null)
                partidas = this.partidas;

            if (partidas.size() > 0) {
                for(Partida partida : partidas) {
                    try {
                        Articulo.Inventario inventario = Articulo.Inventario.Obtener(partida.articulo_id, partida.almacen_id);
                        if (inventario != null) {
                            if (cancelacion) {
                                partida.cantidad = partida.cantidad * -1;
                            }

                            switch (clase) {
                                case "OC":
                                    inventario.setPedido(inventario.getPedido() + partida.cantidad);
                                    break;
                                case "EM":
                                    inventario.setStock(inventario.getStock() + partida.cantidad);
                                    break;
                                case "PE":
                                    inventario.setComprometido(inventario.getComprometido() + partida.cantidad);
                                    break;
                                case "EN":
                                    inventario.setStock(inventario.getStock() - partida.cantidad);
                                    break;
                                case "DV":
                                    inventario.setStock(inventario.getStock() + partida.cantidad);
                                    break;
                                case "FA":
                                    if (reserva)
                                        inventario.setComprometido(inventario.getComprometido() + partida.cantidad);
                                    else
                                        inventario.setStock(inventario.getStock() - partida.cantidad);
                                    break;
                                case "NC":
                                    inventario.setStock(inventario.getStock() + partida.cantidad);
                                    break;
                                case "ND":
                                    inventario.setStock(inventario.getStock() - partida.cantidad);
                                    break;
                                case "ST":
                                    inventario.setPedido(inventario.getPedido() + partida.cantidad);
                                    break;
                                case "TS":
                                    inventario.setStock(inventario.getStock() + partida.cantidad);
                                    break;
                            }

                            inventario.Actualizar();
                        }

                        Articulo.Inventario.Ubicacion inventario_ubicacion = Articulo.Inventario.Ubicacion.Obtener(partida.articulo_id, partida.almacen_id, partida.ubicacion_id);
                        if (inventario_ubicacion != null) {
                            if (cancelacion) {
                                partida.cantidad = partida.cantidad * -1;
                            }

                            switch (clase) {
                                case "EM":
                                    inventario_ubicacion.setStock(inventario.getStock() + partida.cantidad);
                                    break;
                                case "EN":
                                    inventario_ubicacion.setStock(inventario.getStock() - partida.cantidad);
                                    break;
                                case "DV":
                                    inventario_ubicacion.setStock(inventario.getStock() + partida.cantidad);
                                    break;
                                case "FA":
                                    if (!reserva)
                                        inventario_ubicacion.setStock(inventario.getStock() - partida.cantidad);
                                    break;
                                case "NC":
                                    inventario_ubicacion.setStock(inventario.getStock() + partida.cantidad);
                                    break;
                                case "ND":
                                    inventario_ubicacion.setStock(inventario.getStock() - partida.cantidad);
                                    break;
                                case "TS":
                                    inventario_ubicacion.setStock(inventario.getStock() + partida.cantidad);
                                    break;
                            }

                            inventario_ubicacion.Actualizar();
                        }

                    } catch (Exception ex) {
                        continue;
                    }
                }
            }
        } catch (Exception ex) {
            Global.setError(ex);
        }
    }

    private int ObtenerPartidaExistente(Integer articulo_id) {
        for (int i = 0; i < partidas.size(); i++) {
            if (partidas.get(i).getArticulo_id().equals(articulo_id)) {
                return i;
            }
        }
        return -1;
    }

    //region GS
    public Integer getId() {
        return id;
    }

    public void setId(Integer id) {
        this.id = id;
    }

    public Integer getSerie_id() {
        return serie_id;
    }

    public void setSerie_id(Integer serie_id) {
        this.serie_id = serie_id;
    }

    public Integer getCondicion_pago_id() {
        return condicion_pago_id;
    }

    public void setCondicion_pago_id(Integer condicion_pago_id) {
        this.condicion_pago_id = condicion_pago_id;
    }

    public Integer getEstacion_id() {
        return estacion_id;
    }

    public void setEstacion_id(Integer estacion_id) {
        this.estacion_id = estacion_id;
    }

    public Integer getMoneda_id() {
        return moneda_id;
    }

    public void setMoneda_id(Integer moneda_id) {
        this.moneda_id = moneda_id;
    }

    public Double getTipo_cambio() {
        return tipo_cambio;
    }

    public void setTipo_cambio(Double tipo_cambio) {
        this.tipo_cambio = tipo_cambio;
    }

    public Integer getMetodo_pago_id() {
        return metodo_pago_id;
    }

    public void setMetodo_pago_id(Integer metodo_pago_id) {
        this.metodo_pago_id = metodo_pago_id;
    }

    public String getCuenta_pago() {
        return cuenta_pago;
    }

    public void setCuenta_pago(String cuenta_pago) {
        this.cuenta_pago = cuenta_pago;
    }

    public Integer getVendedor_id() {
        return vendedor_id;
    }

    public void setVendedor_id(Integer vendedor_id) {
        this.vendedor_id = vendedor_id;
    }

    public Integer getSocio_id() {
        return socio_id;
    }

    public void setSocio_id(Integer socio_id) {
        this.socio_id = socio_id;
    }

    public Integer getPersona_contacto_id() {
        return persona_contacto_id;
    }

    public void setPersona_contacto_id(Integer persona_contacto_id) {
        this.persona_contacto_id = persona_contacto_id;
    }

    public String getCodigo_sn() {
        return codigo_sn;
    }

    public void setCodigo_sn(String codigo_sn) {
        this.codigo_sn = codigo_sn;
    }

    public Integer getDireccion_facturacion_id() {
        return direccion_facturacion_id;
    }

    public void setDireccion_facturacion_id(Integer direccion_facturacion_id) {
        this.direccion_facturacion_id = direccion_facturacion_id;
    }

    public Integer getDireccion_envio_id() {
        return direccion_envio_id;
    }

    public void setDireccion_envio_id(Integer direccion_envio_id) {
        this.direccion_envio_id = direccion_envio_id;
    }

    public Integer getChofer_id() {
        return chofer_id;
    }

    public void setChofer_id(Integer chofer_id) {
        this.chofer_id = chofer_id;
    }

    public Integer getVehiculo_id() {
        return vehiculo_id;
    }

    public void setVehiculo_id(Integer vehiculo_id) {
        this.vehiculo_id = vehiculo_id;
    }

    public Integer getRuta_id() {
        return ruta_id;
    }

    public void setRuta_id(Integer ruta_id) {
        this.ruta_id = ruta_id;
    }

    public Integer getSupervisor_id() {
        return supervisor_id;
    }

    public void setSupervisor_id(Integer supervisor_id) {
        this.supervisor_id = supervisor_id;
    }

    public Integer getCausalidad_id() {
        return causalidad_id;
    }

    public void setCausalidad_id(Integer causalidad_id) {
        this.causalidad_id = causalidad_id;
    }

    public Integer getCanal_id() {
        return canal_id;
    }

    public void setCanal_id(Integer canal_id) {
        this.canal_id = canal_id;
    }

    public Integer getClase_expedicion_id() {
        return clase_expedicion_id;
    }

    public void setClase_expedicion_id(Integer clase_expedicion_id) {
        this.clase_expedicion_id = clase_expedicion_id;
    }

    public Integer getLista_precio_id() {
        return lista_precio_id;
    }

    public void setLista_precio_id(Integer lista_precio_id) {
        this.lista_precio_id = lista_precio_id;
    }

    public Integer getAlmacen_id() {
        return almacen_id;
    }

    public void setAlmacen_id(Integer almacen_id) {
        this.almacen_id = almacen_id;
    }

    public Integer getAlmacen_destino_id() {
        return almacen_destino_id;
    }

    public void setAlmacen_destino_id(Integer almacen_destino_id) {
        this.almacen_destino_id = almacen_destino_id;
    }

    public Character getTipo() {
        return tipo;
    }

    public void setTipo(Character tipo) {
        this.tipo = tipo;
    }

    public String getClase() {
        return clase;
    }

    public void setClase(String clase) {
        this.clase = clase;
    }

    public Character getEstado() {
        return estado;
    }

    public void setEstado(Character estado) {
        this.estado = estado;
    }

    public Integer getNumero_documento() {
        return numero_documento;
    }

    public void setNumero_documento(Integer numero_documento) {
        this.numero_documento = numero_documento;
    }

    public Double getSubtotal() {
        return subtotal;
    }

    public void setSubtotal(Double subtotal) {
        this.subtotal = subtotal;
    }

    public Double getPorcentaje_descuento() {
        return porcentaje_descuento;
    }

    public void setPorcentaje_descuento(Double porcentaje_descuento) {
        this.porcentaje_descuento = porcentaje_descuento;
    }

    public Double getDescuento() {
        return descuento;
    }

    public void setDescuento(Double descuento) {
        this.descuento = descuento;
    }

    public Double getImpuesto() {
        return impuesto;
    }

    public void setImpuesto(Double impuesto) {
        this.impuesto = impuesto;
    }

    public Double getTotal() {
        return total;
    }

    public void setTotal(Double total) {
        this.total = total;
    }

    public Double getImporte_aplicado() {
        return importe_aplicado;
    }

    public void setImporte_aplicado(Double importe_aplicado) {
        this.importe_aplicado = importe_aplicado;
    }

    public String getOrden_compra() {
        return orden_compra;
    }

    public void setOrden_compra(String orden_compra) {
        this.orden_compra = orden_compra;
    }

    public String getReferencia() {
        return referencia;
    }

    public void setReferencia(String referencia) {
        this.referencia = referencia;
    }

    public String getComentario() {
        return comentario;
    }

    public void setComentario(String comentario) {
        this.comentario = comentario;
    }

    public Boolean getServicio() {
        return servicio;
    }

    public void setServicio(Boolean servicio) {
        this.servicio = servicio;
    }

    public Boolean getReserva() {
        return reserva;
    }

    public void setReserva(Boolean reserva) {
        this.reserva = reserva;
    }

    public Boolean getImpreso() {
        return impreso;
    }

    public void setImpreso(Boolean impreso) {
        this.impreso = impreso;
    }

    public Boolean getCancelado() {
        return cancelado;
    }

    public void setCancelado(Boolean cancelado) {
        this.cancelado = cancelado;
    }

    public Boolean getForaneo() {
        return foraneo;
    }

    public void setForaneo(Boolean foraneo) {
        this.foraneo = foraneo;
    }

    public String getUso_principal() {
        return uso_principal;
    }

    public void setUso_principal(String uso_principal) {
        this.uso_principal = uso_principal;
    }

    public Integer getIdentificador_externo() {
        return identificador_externo;
    }

    public void setIdentificador_externo(Integer identificador_externo) {
        this.identificador_externo = identificador_externo;
    }

    public Integer getNumero_documento_externo() {
        return numero_documento_externo;
    }

    public void setNumero_documento_externo(Integer numero_documento_externo) {
        this.numero_documento_externo = numero_documento_externo;
    }

    public Date getFecha_contabilizacion() {
        return fecha_contabilizacion;
    }

    public void setFecha_contabilizacion(Date fecha_contabilizacion) {
        this.fecha_contabilizacion = fecha_contabilizacion;
    }

    public Date getFecha_vencimiento() {
        return fecha_vencimiento;
    }

    public void setFecha_vencimiento(Date fecha_vencimiento) {
        this.fecha_vencimiento = fecha_vencimiento;
    }

    public Date getFecha_documento() {
        return fecha_documento;
    }

    public void setFecha_documento(Date fecha_documento) {
        this.fecha_documento = fecha_documento;
    }

    public Integer getUsuario_creacion_id() {
        return usuario_creacion_id;
    }

    public void setUsuario_creacion_id(Integer usuario_creacion_id) {
        this.usuario_creacion_id = usuario_creacion_id;
    }

    public Date getFecha_creacion() {
        return fecha_creacion;
    }

    public void setFecha_creacion(Date fecha_creacion) {
        this.fecha_creacion = fecha_creacion;
    }

    public Integer getUsuario_actualizacion_id() {
        return usuario_actualizacion_id;
    }

    public void setUsuario_actualizacion_id(Integer usuario_actualizacion_id) {
        this.usuario_actualizacion_id = usuario_actualizacion_id;
    }

    public Date getFecha_actualizacion() {
        return fecha_actualizacion;
    }

    public void setFecha_actualizacion(Date fecha_actualizacion) {
        this.fecha_actualizacion = fecha_actualizacion;
    }

    public List<Partida> getPartidas() {
        return partidas;
    }

    public void setPartidas(List<Partida> partidas) {
        this.partidas = partidas;
    }

    public List<Flujo> getFlujo() {
        return flujo;
    }

    public void setFlujo(List<Flujo> flujo) {
        this.flujo = flujo;
    }

    public Integer getNumero_partidas() {
        return numero_partidas;
    }

    public void setNumero_partidas(Integer numero_partidas) {
        this.numero_partidas = numero_partidas;
    }

    public Double getCantidad_empaque() {
        return cantidad_empaque;
    }

    public void setCantidad_empaque(Double cantidad_empaque) {
        this.cantidad_empaque = cantidad_empaque;
    }

    public Double getCantidad_partidas() {
        return cantidad_partidas;
    }

    public void setCantidad_partidas(Double cantidad_partidas) {
        this.cantidad_partidas = cantidad_partidas;
    }

    //endregion

    //region Partidas
    @DatabaseTable(tableName = "partidas")
    public static class Partida
    {
        @DatabaseField(columnName = "id", generatedId = true, unique = true)
        @SerializedName("id")
        @Expose
        private Integer id;

        @DatabaseField(columnName = "documento_id")
        @SerializedName("documento_id")
        @Expose
        private Integer documento_id;

        @DatabaseField(columnName = "impuesto_id")
        @SerializedName("impuesto_id")
        @Expose
        private Integer impuesto_id;

        @DatabaseField(columnName = "moneda_id")
        @SerializedName("moneda_id")
        @Expose
        private Integer moneda_id;

        @DatabaseField(columnName = "almacen_id")
        @SerializedName("almacen_id")
        @Expose
        private Integer almacen_id;

        @DatabaseField(columnName = "ubicacion_id")
        @SerializedName("ubicacion_id")
        @Expose
        private Integer ubicacion_id;

        @DatabaseField(columnName = "almacen_destino_id")
        @SerializedName("almacen_destino_id")
        @Expose
        private Integer almacen_destino_id;

        @DatabaseField(columnName = "ubicacion_destingo_id")
        @SerializedName("ubicacion_destino_id")
        @Expose
        private Integer ubicacion_destino_id;

        @DatabaseField(columnName = "articulo_id")
        @SerializedName("articulo_id")
        @Expose
        private Integer articulo_id;

        @DatabaseField(columnName = "unidad_medida_id")
        @SerializedName("unidad_medida_id")
        @Expose
        private Integer unidad_medida_id;

        @DatabaseField(columnName = "tipo_empaque_id")
        @SerializedName("tipo_empaque_id")
        @Expose
        private Integer tipo_empaque_id;

        @DatabaseField(columnName = "sku")
        @SerializedName("sku")
        @Expose
        private String sku;

        @DatabaseField(columnName = "nombre")
        @SerializedName("nombre")
        @Expose
        private String nombre;

        @DatabaseField(columnName = "codigo_barras")
        @SerializedName("codigo_barras")
        @Expose
        private String codigo_barras;

        @DatabaseField(columnName = "cantidad")
        @SerializedName("cantidad")
        @Expose
        private Double cantidad;

        @DatabaseField(columnName = "stock")
        @SerializedName("stock")
        @Expose
        private Double stock;

        @DatabaseField(columnName = "cantidad_empaque")
        @SerializedName("cantidad_empaque")
        @Expose
        private Double cantidad_empaque;

        @DatabaseField(columnName = "cantidad_paquete")
        @SerializedName("cantidad_paquete")
        @Expose
        private Double cantidad_paquete;

        @DatabaseField(columnName = "cantidad_pendiente")
        @SerializedName("cantidad_pendiente")
        @Expose
        private Double cantidad_pendiente;

        @DatabaseField(columnName = "tipo_cambio")
        @SerializedName("tipo_cambio")
        @Expose
        private Double tipo_cambio;

        @DatabaseField(columnName = "precio")
        @SerializedName("precio")
        @Expose
        private Double precio;

        @DatabaseField(columnName = "precio_pieza")
        @SerializedName("precio_pieza")
        @Expose
        private Double precio_pieza;

        @DatabaseField(columnName = "porcentaje_descuento")
        @SerializedName("porcentaje_descuento")
        @Expose
        private Double porcentaje_descuento;

        @DatabaseField(columnName = "descuento")
        @SerializedName("descuento")
        @Expose
        private Double descuento;

        @DatabaseField(columnName = "porcentaje_impuesto")
        @SerializedName("porcentaje_impuesto")
        @Expose
        private Double porcentaje_impuesto;

        @DatabaseField(columnName = "impuesto")
        @SerializedName("impuesto")
        @Expose
        private Double impuesto;

        @DatabaseField(columnName = "subtotal")
        @SerializedName("subtotal")
        @Expose
        private Double subtotal;

        @DatabaseField(columnName = "total")
        @SerializedName("total")
        @Expose
        private Double total;

        @DatabaseField(columnName = "comentario")
        @SerializedName("comentario")
        @Expose
        private String comentario;

        @DatabaseField(columnName = "norma_reparto")
        @SerializedName("norma_reparto")
        @Expose
        private String norma_reparto;

        @DatabaseField(columnName = "usuario_creacion_id")
        @SerializedName("usuario_creacion_id")
        @Expose
        private Integer usuario_creacion_id;

        @DatabaseField(columnName = "fecha_creacion")
        private transient Date fecha_creacion;

        @DatabaseField(columnName = "usuario_actualizacion_id")
        @SerializedName("usuario_actualizacion_id")
        @Expose
        private Integer usuario_actualizacion_id;

        @DatabaseField(columnName = "fecha_actualizacion")
        private transient Date fecha_actualizacion;

        @DatabaseField(columnName = "fecha_lectura")
        private transient Date fecha_lectura;
        //Uso interno
        private Double diferencia;

        public static Dao Partidas()
        {
            try {
                return MainActivity.db.Partidas();
            } catch (Exception ex) {
                return null;
            }
        }

        public Partida()
        {
            impuesto_id = Global.getConfiguracion().getImpuesto_id();
            almacen_id = Global.getUsuario().getAlmacen_id();
            unidad_medida_id = ubicacion_id = almacen_destino_id = ubicacion_destino_id = 0;
            cantidad = 1.0;
            cantidad_empaque = 0.0;
            comentario = norma_reparto = "";
            usuario_creacion_id = Global.getUsuario().getId();
            fecha_creacion = Functions.getCurrentDateTime();
            usuario_actualizacion_id = Global.getUsuario().getId();
            fecha_actualizacion = Functions.getCurrentDateTime();
            fecha_lectura = Functions.getCurrentDateTime();
        }

        public Boolean Agregar()
        {
            try {
                Partidas().create(this);
                return true;
            }
            catch (Exception ex) {
                Global.setError(ex);
                return false;
            }
        }

        public static Partida Obtener(Integer id)
        {
            try
            {
                return (Partida) Partidas().queryForId(id);
            } catch (Exception ex) {
                Global.setError(ex);
                return null;
            }
        }

        public static Partida ObtenerPorSKU(Integer documento_id, String sku)
        {
            try
            {
                return (Partida) Partidas().queryBuilder().where().eq("documento_id", documento_id).and().eq("sku", sku).queryForFirst();
            } catch (Exception ex) {
                Global.setError(ex);
                return null;
            }
        }

        public Boolean Actualizar()
        {
            try {
                usuario_actualizacion_id = Global.getUsuario().getId();
                fecha_actualizacion = Functions.getCurrentDateTime();
                Partidas().update(this);
                return true;
            }  catch (Exception ex) {
                Global.setError(ex);
                return false;
            }
        }

        //Funciones
        public void ObtenerStock() {
            try {
                Almacen almacen = Almacen.Obtener(almacen_id);

                if (almacen.getUbicaciones())
                {
                    Articulo.Inventario.Ubicacion inventario = (Articulo.Inventario.Ubicacion) Articulo.Inventario.Ubicacion.Ubicaciones().queryBuilder().where().eq("articulo_id", articulo_id).and().eq("almacen_id", almacen_id).and().eq("ubicacion_id", ubicacion_id).queryForFirst();

                    if (inventario != null) {
                        stock = inventario.getStock();
                    } else {
                        stock = 0.0;
                    }
                }
                else
                {
                    Articulo.Inventario inventario = (Articulo.Inventario) Articulo.Inventario.Inventarios().queryBuilder().where().eq("articulo_id", articulo_id).and().eq("almacen_id", almacen_id).queryForFirst();

                    if (inventario != null) {
                        stock = inventario.getStock();
                    } else {
                        stock = 0.0;
                    }
                }
            } catch (Exception ex) {
                stock = 0.0;
            }
        }

        private Boolean ObtenerPrecio(Integer socio_id, Integer lista_precio_id) {
            try {
                Articulo.Precio precio = Articulo.Precio.Obtener(articulo_id, lista_precio_id, unidad_medida_id);

                if (precio != null) {
                    moneda_id = precio.getMoneda_id();

                    if (moneda_id == 0) {
                        Global.setError(new Exception("Aún no se ha establecido una moneda."));
                        return false;
                    }

                    tipo_cambio = ObtenerTipoCambio(moneda_id, tipo_cambio);
                    this.precio = precio.getPrecio();

                    Impuesto impuesto = Articulo.ObtenerImpuesto(articulo_id, socio_id);
                    if (impuesto != null) {
                        if (impuesto.getId() != 0) {
                            impuesto_id = impuesto.getId();
                            porcentaje_impuesto = impuesto.getPorcentaje();
                        }
                    } else {
                        Global.setError(new Exception("Aún no se ha establecido un impuesto."));
                        return false;
                    }
                } else {
                    return  false;
                }

                return true;
            } catch (Exception ex) {
                precio = 0.0;
                return  false;
            }
        }

        public Double ObtenerTipoCambio(Integer moneda_documento,Double tipo_cambio_documento) {
            try {
                if (Global.getConfiguracion().getMoneda_id() != moneda_id) {
                    if (moneda_id != moneda_documento) {
                        if (documento_id != 0) {
                            Documento documento = Documento.Obtener(documento_id);
                            if (documento != null) {
                                return documento.tipo_cambio;
                            } else {
                                return 1.0;
                            }
                        } else {
                            Double tipo_cambio = TipoCambio.Venta(moneda_id);
                            if (tipo_cambio != null) {
                                return  tipo_cambio;
                            } else {
                                return 1.0;
                            }
                        }
                    } else {
                        return tipo_cambio_documento;
                    }
                } else {
                    return 1.0;
                }
            } catch (Exception ex) {
                return  1.0;
            }
        }

        public void ModificarTipoCambio(Double tipo_cambio)
        {
            this.tipo_cambio = tipo_cambio;
            CalcularTotal();
        }

        public void CalcularCantidadPendiente(Integer documento_id) {
            try {
                cantidad_pendiente = cantidad;
            } catch (Exception ex) {
                cantidad_pendiente = cantidad;
            } finally {
                CalcularTotal();
            }
        }

        public void CalcularTotal() {
            if (tipo_cambio == null)
            {
                tipo_cambio = 1.0;
            }

            Double precio_por_tc = precio * tipo_cambio;

            precio_pieza = (cantidad_paquete != 0) ? precio / cantidad_paquete : precio;
            if (porcentaje_descuento != null) {
                porcentaje_descuento = (porcentaje_descuento > 100) ? 100 : porcentaje_descuento;
            } else {
                porcentaje_descuento = 0.0;
            }

            descuento = (porcentaje_descuento / 100) * precio_por_tc;
            impuesto = (porcentaje_impuesto / 100) * (precio_por_tc - descuento);
            subtotal = cantidad * (precio_por_tc - descuento);

            total = (cantidad * impuesto) + subtotal;
        }

        public Boolean VerificarExistencia() {
            try {
                Articulo articulo = Articulo.Obtener(articulo_id);
                if (articulo != null) {
                    if (articulo.getAlmacenable()) {
                        ObtenerStock();
                        if (stock < cantidad) {
                            Global.setError(new Exception(String.format("La cantidad recae en un inventario negativo (Stock actual %s del artículo %s).", stock, sku)));
                            return  false;
                        }
                    }
                }

                return true;
            } catch (Exception ex) {
                Global.setError(ex);
                return false;
            }
        }

        public void ModificarTotal()
        {
            Double total = cantidad * ((precio * tipo_cambio) + impuesto);

            porcentaje_descuento = 100 - ((this.total / total) * 100);
            if (porcentaje_descuento > 100) {
                porcentaje_descuento = 100.0;
            } else if (porcentaje_descuento <= 0) {
                porcentaje_descuento = 0.0;
            }

            CalcularTotal();
        }

        //region GS
        public Integer getId() {
            return id;
        }

        public void setId(Integer id) {
            this.id = id;
        }

        public Integer getDocumento_id() {
            return documento_id;
        }

        public void setDocumento_id(Integer documento_id) {
            this.documento_id = documento_id;
        }

        public Integer getImpuesto_id() {
            return impuesto_id;
        }

        public void setImpuesto_id(Integer impuesto_id) {
            this.impuesto_id = impuesto_id;
        }

        public Integer getMoneda_id() {
            return moneda_id;
        }

        public void setMoneda_id(Integer moneda_id) {
            this.moneda_id = moneda_id;
        }

        public Integer getAlmacen_id() {
            return almacen_id;
        }

        public void setAlmacen_id(Integer almacen_id) {
            this.almacen_id = almacen_id;
        }

        public Integer getUbicacion_id() {
            return ubicacion_id;
        }

        public void setUbicacion_id(Integer ubicacion_id) {
            this.ubicacion_id = ubicacion_id;
        }

        public Integer getAlmacen_destino_id() {
            return almacen_destino_id;
        }

        public void setAlmacen_destino_id(Integer almacen_destino_id) {
            this.almacen_destino_id = almacen_destino_id;
        }

        public Integer getUbicacion_destino_id() {
            return ubicacion_destino_id;
        }

        public void setUbicacion_destino_id(Integer ubicacion_destino_id) {
            this.ubicacion_destino_id = ubicacion_destino_id;
        }

        public Integer getArticulo_id() {
            return articulo_id;
        }

        public void setArticulo_id(Integer articulo_id) {
            this.articulo_id = articulo_id;
        }

        public Integer getUnidad_medida_id() {
            return unidad_medida_id;
        }

        public void setUnidad_medida_id(Integer unidad_medida_id) {
            this.unidad_medida_id = unidad_medida_id;
        }

        public Integer getTipo_empaque_id() {
            return tipo_empaque_id;
        }

        public void setTipo_empaque_id(Integer tipo_empaque_id) {
            this.tipo_empaque_id = tipo_empaque_id;
        }

        public String getSku() {
            return sku;
        }

        public void setSku(String sku) {
            this.sku = sku;
        }

        public String getNombre() {
            return nombre;
        }

        public void setNombre(String nombre) {
            this.nombre = nombre;
        }

        public String getCodigo_barras() {
            return codigo_barras;
        }

        public void setCodigo_barras(String codigo_barras) {
            this.codigo_barras = codigo_barras;
        }

        public Double getCantidad() {
            return cantidad;
        }

        public void setCantidad(Double cantidad) {
            this.cantidad = cantidad;
        }

        public Double getCantidad_empaque() {
            return cantidad_empaque;
        }

        public void setCantidad_empaque(Double cantidad_empaque) {
            this.cantidad_empaque = cantidad_empaque;
        }

        public Double getCantidad_paquete() {
            return cantidad_paquete;
        }

        public void setCantidad_paquete(Double cantidad_paquete) {
            this.cantidad_paquete = cantidad_paquete;
        }

        public Double getCantidad_pendiente() {
            return cantidad_pendiente;
        }

        public void setCantidad_pendiente(Double cantidad_pendiente) {
            this.cantidad_pendiente = cantidad_pendiente;
        }

        public Double getTipo_cambio() {
            return tipo_cambio;
        }

        public void setTipo_cambio(Double tipo_cambio) {
            this.tipo_cambio = tipo_cambio;
        }

        public Double getPrecio() {
            return precio;
        }

        public void setPrecio(Double precio) {
            this.precio = precio;
        }

        public Double getPrecio_pieza() {
            return precio_pieza;
        }

        public void setPrecio_pieza(Double precio_pieza) {
            this.precio_pieza = precio_pieza;
        }

        public Double getPorcentaje_descuento() {
            return porcentaje_descuento;
        }

        public void setPorcentaje_descuento(Double porcentaje_descuento) {
            this.porcentaje_descuento = porcentaje_descuento;
        }

        public Double getDescuento() {
            return descuento;
        }

        public void setDescuento(Double descuento) {
            this.descuento = descuento;
        }

        public Double getPorcentaje_impuesto() {
            return porcentaje_impuesto;
        }

        public void setPorcentaje_impuesto(Double porcentaje_impuesto) {
            this.porcentaje_impuesto = porcentaje_impuesto;
        }

        public Double getImpuesto() {
            return impuesto;
        }

        public void setImpuesto(Double impuesto) {
            this.impuesto = impuesto;
        }

        public Double getSubtotal() {
            return subtotal;
        }

        public void setSubtotal(Double subtotal) {
            this.subtotal = subtotal;
        }

        public Double getTotal() {
            return total;
        }

        public void setTotal(Double total) {
            this.total = total;
        }

        public String getComentario() {
            return comentario;
        }

        public void setComentario(String comentario) {
            this.comentario = comentario;
        }

        public String getNorma_reparto() {
            return norma_reparto;
        }

        public void setNorma_reparto(String norma_reparto) {
            this.norma_reparto = norma_reparto;
        }

        public Integer getUsuario_creacion_id() {
            return usuario_creacion_id;
        }

        public void setUsuario_creacion_id(Integer usuario_creacion_id) {
            this.usuario_creacion_id = usuario_creacion_id;
        }

        public Date getFecha_creacion() {
            return fecha_creacion;
        }

        public void setFecha_creacion(Date fecha_creacion) {
            this.fecha_creacion = fecha_creacion;
        }

        public Integer getUsuario_actualizacion_id() {
            return usuario_actualizacion_id;
        }

        public void setUsuario_actualizacion_id(Integer usuario_actualizacion_id) {
            this.usuario_actualizacion_id = usuario_actualizacion_id;
        }

        public Date getFecha_actualizacion() {
            return fecha_actualizacion;
        }

        public void setFecha_actualizacion(Date fecha_actualizacion) {
            this.fecha_actualizacion = fecha_actualizacion;
        }

        public Date getFecha_lectura() {
            return fecha_lectura;
        }

        public void setFecha_lectura(Date fecha_lectura) {
            this.fecha_lectura = fecha_lectura;
        }

        public Double getStock() {
            return stock;
        }

        public void setStock(Double stock) {
            this.stock = stock;
        }

        public Double getDiferencia() {
            return cantidad - stock;
        }

        public void setDiferencia(Double diferencia) {
            this.diferencia = diferencia;
        }
        //endregion
    }
    //endregion

    //region Tipo
    public static class Tipo
    {
        private Character tipo;
        private String nombre;
        private static List<Tipo> Tipos()
        {
            List<Tipo> tipos = new ArrayList<Tipo>();

            Tipo clase = new Tipo();

            clase.tipo = 'V';
            clase.nombre = "Venta";
            tipos.add(clase);

            clase = new Tipo();

            clase.tipo = 'C';
            clase.nombre = "Compra";
            tipos.add(clase);

            clase = new Tipo();

            clase.tipo = 'I';
            clase.nombre = "Operación de inventario";
            tipos.add(clase);

            return tipos;
        }

        public static Character ObtenerPredeterminado()
        {
            return 'V';
        }
    }
//endregion

    //region Clase
    public static class Clase
    {
        private Character tipo;
        private String clase;
        private String nombre;

        public static List<Clase> Clases() {
            List<Clase> clases = new ArrayList<Clase>();

            //Ventas
            Clase clase = new Clase();

            clase.tipo = 'V';
            clase.clase = "CO";
            clase.nombre = "Cotización";
            clases.add(clase);

            clase = new Clase();

            clase.tipo = 'V';
            clase.clase = "PE";
            clase.nombre = "Pedido";
            clases.add(clase);

            clase = new Clase();

            clase.tipo = 'V';
            clase.clase = "EN";
            clase.nombre = "Entrega";
            clases.add(clase);

            clase = new Clase();

            clase.tipo = 'V';
            clase.clase = "AN";
            clase.nombre = "Factura de anticipo";
            clases.add(clase);

            clase = new Clase();

            clase.tipo = 'V';
            clase.clase = "FA";
            clase.nombre = "Factura de cliente";
            clases.add(clase);

            clase = new Clase();

            clase.tipo = 'V';
            clase.clase = "DV";
            clase.nombre = "Devolución";
            clases.add(clase);

            clase = new Clase();

            clase.tipo = 'V';
            clase.clase = "NC";
            clase.nombre = "Nota de crédito";
            clases.add(clase);

            clase = new Clase();

            clase.tipo = 'V';
            clase.clase = "ND";
            clase.nombre = "Nota de débito";
            clases.add(clase);

            //Pagos
            clase = new Clase();

            clase.tipo = 'P';
            clase.clase = "PR";
            clase.nombre = "Pago recibido";
            clases.add(clase);

            //Operaciones de stock
            clase = new Clase();

            clase.tipo = 'I';
            clase.clase = "ST";
            clase.nombre = "Solicitud de traslado";
            clases.add(clase);

            clase = new Clase();

            clase.tipo = 'I';
            clase.clase = "TS";
            clase.nombre = "Transferencia de stock";
            clases.add(clase);

            clase = new Clase();

            clase.tipo = 'I';
            clase.clase = "IF";
            clase.nombre = "Inventarios físicos";
            clases.add(clase);

            //Compras
            clase = new Clase();

            clase.tipo = 'C';
            clase.clase = "CC";
            clase.nombre = "Cotización de compra";
            clases.add(clase);

            clase = new Clase();

            clase.tipo = 'C';
            clase.clase = "OC";
            clase.nombre = "Orden de compra";
            clases.add(clase);

            clase = new Clase();

            clase.tipo = 'C';
            clase.clase = "EM";
            clase.nombre = "Entrada de mercancías";
            clases.add(clase);

            clase = new Clase();

            clase.tipo = 'C';
            clase.clase = "DM";
            clase.nombre = "Devolución de mercancías";
            clases.add(clase);

            clase = new Clase();

            clase.tipo = 'C';
            clase.clase = "FP";
            clase.nombre = "Factura de proveedor";
            clases.add(clase);

            return clases;
        }

        public static Clase ObtenerPredeterminado()
        {
            Clase clase = new Clase();

            clase.tipo = 'V';
            clase.clase = "PE";
            clase.nombre = "Pedido";

            return clase;
        }

        public List<String> CopiarA()
        {
            List<String> clases = new ArrayList<>();
            
            switch (clase)
            {
                //Ventas
                case "CO":
                    clases.add("PE");
                    clases.add("EN");
                case "PE":
                    clases.add("EN");
                    break;
            }

            return clases;
        }

        public List<String> CopiarDe()
        {
            List<String> clases = new ArrayList<>();

            switch (clase)
            {
                //Ventas
                case "PE":
                    clases.add("CO");
                case "EN":
                    clases.add("CO");
                    clases.add("PE");
                    break;
            }

            return clases;
        }
        
        public Character getTipo() {
            return tipo;
        }

        public void setTipo(Character tipo) {
            this.tipo = tipo;
        }

        public String getClase() {
            return clase;
        }

        public void setClase(String clase) {
            this.clase = clase;
        }

        public String getNombre() {
            return nombre;
        }

        public void setNombre(String nombre) {
            this.nombre = nombre;
        }
    }
    //endregion

    //region Estado
    public static class Estado
    {
        private Character estado;
        private String nombre;

        public static List<Estado> Estados()
        {
            List<Estado> estados = new ArrayList<Estado>();

            Estado estado = new Estado();

            estado.estado = 'A';
            estado.nombre = "Abierto";
            estados.add(estado);

            estado = new Estado();

            estado.estado = 'C';
            estado.nombre = "Cerrado";
            estados.add(estado);

            estado = new Estado();

            estado.estado = 'B';
            estado.nombre = "Borrador";
            estados.add(estado);

            estado = new Estado();

            estado.estado = 'P';
            estado.nombre = "Pendiente";
            estados.add(estado);

            return estados;
        }

        public static Character ObtenerPredeterminado()
        {
            return 'A';
        }
    }
//endregion
}