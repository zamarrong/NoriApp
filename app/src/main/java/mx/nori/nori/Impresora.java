package mx.nori.nori;

import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothDevice;
import android.media.audiofx.Visualizer;
import android.util.Log;

import java.util.Collections;
import java.util.List;

import mx.nori.nori.NoriSDK.Actividad;
import mx.nori.nori.NoriSDK.Almacen;
import mx.nori.nori.NoriSDK.Articulo;
import mx.nori.nori.NoriSDK.Causalidad;
import mx.nori.nori.NoriSDK.Documento;
import mx.nori.nori.NoriSDK.Empresa;
import mx.nori.nori.NoriSDK.Flujo;
import mx.nori.nori.NoriSDK.Global;
import mx.nori.nori.NoriSDK.MetodoPago;
import mx.nori.nori.NoriSDK.Socio;
import mx.nori.nori.NoriSDK.Vendedor;

public class Impresora
{
    BluetoothAdapter btAdapter;
    BluetoothDevice mBtDevice;

    public Impresora()
    {
        btAdapter = BluetoothAdapter.getDefaultAdapter();
        mBtDevice = btAdapter.getBondedDevices().iterator().next();
    }

    public void ImprimirDocumento(final Documento documento)
    {
        try {
            final BluetoothPrinter mPrinter = new BluetoothPrinter(mBtDevice);
            mPrinter.connectPrinter(new BluetoothPrinter.PrinterConnectListener() {
                @Override
                public void onConnected() {
                    Empresa empresa = Empresa.Obtener();
                    Socio socio = Socio.Obtener(documento.getSocio_id());

                    String clase;
                    switch (documento.getClase()) {
                        case "CO":
                            clase = "Cotización";
                            break;
                        case "PE":
                            clase = "Pedido";
                            break;
                        case "EN":
                            clase = "Entrega";
                            break;
                        default:
                            clase = "Documento " + documento.getClase();
                            break;
                    }

                    mPrinter.setAlign(BluetoothPrinter.ALIGN_CENTER);

                    mPrinter.addNewLine();
                    mPrinter.printText(empresa.getNombre_fiscal());
                    mPrinter.addNewLine();

                    mPrinter.setAlign(BluetoothPrinter.ALIGN_LEFT);

                    mPrinter.printText("R.F.C. " + empresa.getRfc());
                    mPrinter.addNewLine();

                    mPrinter.printText("Tel. " + empresa.getTelefono());
                    mPrinter.addNewLine();

                    mPrinter.setAlign(BluetoothPrinter.ALIGN_CENTER);

                    mPrinter.printText("--------------------------");
                    mPrinter.addNewLine();

                    mPrinter.setAlign(BluetoothPrinter.ALIGN_LEFT);

                    mPrinter.printText("ID: " + documento.getId() + " FECHA: " + Functions.toDateTimeString(documento.getFecha_creacion()));
                    mPrinter.addNewLine();

                    mPrinter.printText("SOCIO: " + socio.getCodigo());
                    mPrinter.addNewLine();

                    mPrinter.setAlign(BluetoothPrinter.ALIGN_CENTER);

                    mPrinter.setBold(true);
                    mPrinter.printText(socio.getNombre());
                    mPrinter.addNewLine();
                    mPrinter.setBold(false);

                    mPrinter.printText("--------------------------");
                    mPrinter.addNewLine();

                    mPrinter.setBold(true);
                    mPrinter.printText(clase);
                    mPrinter.addNewLine();
                    mPrinter.setBold(false);

                    if (documento.getCancelado()) {
                        mPrinter.setBold(true);
                        mPrinter.printText("-- CANCELADO --");
                        mPrinter.addNewLine();
                        mPrinter.setBold(false);
                    }

                    mPrinter.setAlign(BluetoothPrinter.ALIGN_LEFT);

                    mPrinter.setBold(true);
                    mPrinter.printText("CANT    PRECIO          SUBTOTAL");
                    //mPrinter.addNewLine();
                    //mPrinter.printText("CÓDIGO DE ARTÍCULO");
                    mPrinter.addNewLine();
                    mPrinter.printText("DESCRIPCIÓN");
                    mPrinter.addNewLine();
                    mPrinter.setBold(false);

                    for(Documento.Partida partida : documento.getPartidas()) {
                        mPrinter.printText(String.format("%s    %s          %s", partida.getCantidad(), partida.getPrecio(), partida.getSubtotal()));
                        mPrinter.addNewLine();

                        //mPrinter.setBold(true);
                        //mPrinter.printText(partida.getSku());
                        //mPrinter.addNewLine();

                        mPrinter.setBold(false);
                        mPrinter.printText(partida.getNombre());
                        mPrinter.addNewLine();
                    }

                    mPrinter.setAlign(BluetoothPrinter.ALIGN_RIGHT);

                    mPrinter.printText("SUBTOTAL " + Functions.toCurrency(documento.getSubtotal()));
                    mPrinter.addNewLine();

                    mPrinter.printText("DESCUENTO " + Functions.toCurrency(documento.getDescuento()));
                    mPrinter.addNewLine();

                    mPrinter.printText("IMPUESTO " + Functions.toCurrency(documento.getImpuesto()));
                    mPrinter.addNewLine();

                    mPrinter.printText("--------------");
                    mPrinter.addNewLine();

                    mPrinter.setBold(true);
                    mPrinter.printText("TOTAL " + Functions.toCurrency(documento.getTotal()));
                    mPrinter.addNewLine();
                    mPrinter.setBold(false);

                    mPrinter.printText("--------------");
                    mPrinter.addNewLine();

                    if (documento.getFlujo().size() > 0) {
                        mPrinter.setBold(true);
                        mPrinter.printText("FORMA PAGO  TC  IMPORTE    TOTAL");
                        mPrinter.addNewLine();
                        mPrinter.addNewLine();
                        mPrinter.setBold(false);

                        for (Flujo flujo : documento.getFlujo()) {
                            MetodoPago.Tipo tipo_metodo_pago = MetodoPago.Tipo.Obtener(flujo.getTipo_metodo_pago_id());
                            if (tipo_metodo_pago != null) {
                                mPrinter.printText(String.format("%s   %s  %s    %s", tipo_metodo_pago.getNombre(), flujo.getTipo_cambio().toString(), flujo.getImporte().toString(), Functions.toCurrency(flujo.getTipo_cambio() * flujo.getImporte())));
                                mPrinter.addNewLine();
                            }
                        }
                    }

                    if (documento.getClase().equals("EN") && documento.getTotal() > documento.getImporte_aplicado()) {
                        mPrinter.setAlign(BluetoothPrinter.ALIGN_CENTER);
                        mPrinter.printText(String.format("Por este pagare me (nos) comprometo (mos) a pagar incondicionalmente a la orden de %s en donde se me(nos) requiera, el día %s, la cantidad de %s, importe de la mercancía recibida a mi (nuestra) entera satisfacción. El presente pagare causara un interés moratorio a razón del 4.5%% (cuatro punto cinco por ciento) mensual sobre la cantidad insoluta,  desde la fecha de vencimiento del presente hasta el día de su liquidación pagadero en esta ciudad juntamente con el principal.", empresa.getNombre_fiscal(), Functions.toDateString(documento.getFecha_vencimiento()), Functions.toCurrency(documento.getTotal())));
                        mPrinter.addNewLine();

                        mPrinter.feedPaper();
                        mPrinter.printLine();
                        mPrinter.printText("FIRMA");
                        mPrinter.addNewLine();
                    }

                    mPrinter.setAlign(BluetoothPrinter.ALIGN_LEFT);

                    mPrinter.printText("VENDEDOR: " + Global.getUsuario().getNombre());

                    mPrinter.feedPaper();
                    mPrinter.finish();
                }

                @Override
                public void onFailed() {
                    Log.d("BluetoothPrinter", "Conexión fallida");
                }
            });
        } catch (Exception ex) {
            Log.d("BluetoothPrinter", ex.getMessage());
        }
    }

    public void ImprimirActividad(final Actividad actividad)
    {
        try {
            final BluetoothPrinter mPrinter = new BluetoothPrinter(mBtDevice);
            mPrinter.connectPrinter(new BluetoothPrinter.PrinterConnectListener() {
                @Override
                public void onConnected() {
                    Empresa empresa = Empresa.Obtener();
                    Socio socio = Socio.Obtener(actividad.getSocio_id());

                    mPrinter.setAlign(BluetoothPrinter.ALIGN_CENTER);

                    mPrinter.addNewLine();
                    mPrinter.printText(empresa.getNombre_fiscal());
                    mPrinter.addNewLine();

                    mPrinter.setAlign(BluetoothPrinter.ALIGN_LEFT);

                    mPrinter.printText("R.F.C. " + empresa.getRfc());
                    mPrinter.addNewLine();

                    mPrinter.printText("Tel. " + empresa.getTelefono());
                    mPrinter.addNewLine();

                    mPrinter.setAlign(BluetoothPrinter.ALIGN_CENTER);

                    mPrinter.printText("--------------------------");
                    mPrinter.addNewLine();

                    mPrinter.setAlign(BluetoothPrinter.ALIGN_LEFT);

                    mPrinter.printText("ID: " + actividad.getId() + " FECHA: " + Functions.toDateTimeString(actividad.getFecha_creacion()));
                    mPrinter.addNewLine();

                    mPrinter.printText("SOCIO: " + socio.getCodigo());
                    mPrinter.addNewLine();

                    mPrinter.setAlign(BluetoothPrinter.ALIGN_CENTER);

                    mPrinter.setBold(true);
                    mPrinter.printText(socio.getNombre());
                    mPrinter.addNewLine();
                    mPrinter.setBold(false);

                    mPrinter.printText("--------------------------");
                    mPrinter.addNewLine();

                    Actividad.Tipo tipo_actividad = Actividad.Tipo.Obtener(actividad.getTipo_actividad_id());

                    if (tipo_actividad != null) {
                        mPrinter.setBold(true);
                        mPrinter.printText(tipo_actividad.getNombre());
                        mPrinter.addNewLine();
                        mPrinter.setBold(false);
                    }

                    mPrinter.setAlign(BluetoothPrinter.ALIGN_LEFT);

                    Causalidad causalidad = Causalidad.Obtener(actividad.getCausalidad_id());

                    if (causalidad != null) {
                        mPrinter.printText("CAUSALIDAD: " + causalidad.getNombre());
                        mPrinter.addNewLine();
                    }

                    mPrinter.setBold(true);
                    mPrinter.printText("COMENTARIOS:");
                    mPrinter.addNewLine();
                    mPrinter.setBold(false);

                    mPrinter.printText(actividad.getComentarios());
                    mPrinter.addNewLine();

                    mPrinter.setBold(true);
                    mPrinter.printText("NOTAS:");
                    mPrinter.addNewLine();
                    mPrinter.setBold(false);

                    mPrinter.printText(actividad.getNotas());
                    mPrinter.addNewLine();

                    mPrinter.setAlign(BluetoothPrinter.ALIGN_CENTER);

                    mPrinter.feedPaper();
                    mPrinter.printLine();
                    mPrinter.printText("FIRMA");
                    mPrinter.addNewLine();

                    mPrinter.setAlign(BluetoothPrinter.ALIGN_LEFT);

                    Vendedor vendedor = Vendedor.Obtener(actividad.getVendedor_id());
                    if (vendedor != null) {
                        mPrinter.printText("VENDEDOR: " + vendedor.getNombre());
                    } else {
                        mPrinter.printText("VENDEDOR: " + Global.getUsuario().getNombre());
                    }

                    mPrinter.feedPaper();
                    mPrinter.finish();
                }

                @Override
                public void onFailed() {
                    Log.d("BluetoothPrinter", "Conexión fallida");
                }
            });
        } catch (Exception ex) {
            Log.d("BluetoothPrinter", ex.getMessage());
        }
    }

    public void ImprimirInventario()
    {
        try {
            final BluetoothPrinter mPrinter = new BluetoothPrinter(mBtDevice);
            mPrinter.connectPrinter(new BluetoothPrinter.PrinterConnectListener() {
                @Override
                public void onConnected() {
                    Empresa empresa = Empresa.Obtener();
                    Almacen almacen = Almacen.Obtener(Global.getUsuario().getAlmacen_id());

                    mPrinter.setAlign(BluetoothPrinter.ALIGN_CENTER);

                    mPrinter.addNewLine();
                    mPrinter.printText(empresa.getNombre_fiscal());
                    mPrinter.addNewLine();

                    mPrinter.setAlign(BluetoothPrinter.ALIGN_LEFT);

                    mPrinter.printText("R.F.C. " + empresa.getRfc());
                    mPrinter.addNewLine();

                    mPrinter.printText("Tel. " + empresa.getTelefono());
                    mPrinter.addNewLine();

                    mPrinter.setAlign(BluetoothPrinter.ALIGN_CENTER);

                    mPrinter.printText("--------------------------");
                    mPrinter.addNewLine();

                    mPrinter.setBold(true);
                    mPrinter.printText("INVENTARIO");
                    mPrinter.addNewLine();
                    if (almacen != null) {
                        mPrinter.printText(almacen.getCodigo());
                        mPrinter.addNewLine();
                    }
                    mPrinter.setBold(false);

                    mPrinter.setAlign(BluetoothPrinter.ALIGN_LEFT);

                    mPrinter.setBold(true);
                    mPrinter.printText("CANT   CÓDIGO DE ARTÍCULO");
                    mPrinter.addNewLine();
                    mPrinter.printText("DESCRIPCIÓN");
                    mPrinter.addNewLine();
                    mPrinter.setBold(false);

                    try {
                        List<Articulo.Inventario> inventarios = Articulo.Inventario.Inventarios().queryBuilder().where().eq("almacen_id", Global.getUsuario().getAlmacen_id()).and().rawComparison("stock", ">", 0).query();
                        for (Articulo.Inventario inventario : inventarios) {
                            Articulo articulo = Articulo.Obtener(inventario.getArticulo_id());

                            if (articulo != null) {
                                mPrinter.printText(String.format("%s   %s", inventario.getStock().toString(), articulo.getSku()));
                                mPrinter.addNewLine();
                                mPrinter.printText(articulo.getNombre());
                                mPrinter.addNewLine();
                                mPrinter.printLine();
                            }
                        }
                    } catch (Exception ex) {
                        mPrinter.printText(String.format("Error al obtener el inventario: %s", ex.getMessage()));
                        mPrinter.addNewLine();
                    }

                    mPrinter.feedPaper();
                    mPrinter.finish();
                }

                @Override
                public void onFailed() {
                    Log.d("BluetoothPrinter", "Conexión fallida");
                }
            });
        } catch (Exception ex) {
            Log.d("BluetoothPrinter", ex.getMessage());
        }
    }

    public void ImprimirFlujo()
    {
        try {
            final BluetoothPrinter mPrinter = new BluetoothPrinter(mBtDevice);
            mPrinter.connectPrinter(new BluetoothPrinter.PrinterConnectListener() {
                @Override
                public void onConnected() {
                    Empresa empresa = Empresa.Obtener();

                    mPrinter.setAlign(BluetoothPrinter.ALIGN_CENTER);

                    mPrinter.addNewLine();
                    mPrinter.printText(empresa.getNombre_fiscal());
                    mPrinter.addNewLine();

                    mPrinter.setAlign(BluetoothPrinter.ALIGN_LEFT);

                    mPrinter.printText("R.F.C. " + empresa.getRfc());
                    mPrinter.addNewLine();

                    mPrinter.printText("Tel. " + empresa.getTelefono());
                    mPrinter.addNewLine();

                    mPrinter.setAlign(BluetoothPrinter.ALIGN_CENTER);

                    mPrinter.printText("--------------------------");
                    mPrinter.addNewLine();

                    mPrinter.setBold(true);
                    mPrinter.printText("FLUJO");
                    mPrinter.addNewLine();
                    mPrinter.setBold(false);

                    mPrinter.setAlign(BluetoothPrinter.ALIGN_LEFT);

                    mPrinter.setBold(true);
                    mPrinter.printText("CLIENTE");
                    mPrinter.addNewLine();
                    mPrinter.printText("DOCUMENTO  FORMA PAGO    IMPORTE");
                    mPrinter.addNewLine();
                    mPrinter.setBold(false);

                    try {
                        List<Documento> documentos = Documento.Documentos().queryBuilder().orderBy("socio_id", false).where().eq("clase", "EN").and().rawComparison("fecha_documento", ">=", Functions.getCurrentDate()).and().rawComparison("importe_aplicado", ">", 0).query();

                        Double total_flujo = 0.0;
                        int index_documento = 0;
                        for (Documento documento : documentos) {
                            Socio socio = Socio.Obtener(documento.getSocio_id());
                            List<Flujo> flujos = documento.ObtenerFlujo();
                            if (socio != null && flujos.size() > 0) {
                                for (Flujo flujo : flujos) {
                                    MetodoPago.Tipo tipo_metodo_pago = MetodoPago.Tipo.Obtener(flujo.getTipo_metodo_pago_id());
                                    if (tipo_metodo_pago != null) {
                                        mPrinter.printText(socio.getNombre());
                                        mPrinter.addNewLine();

                                        mPrinter.printText(String.format("%s  %s    %s", documento.getId().toString(), tipo_metodo_pago.getNombre(), Functions.toCurrency(flujo.getTipo_cambio() * flujo.getImporte())));
                                        mPrinter.addNewLine();
                                        mPrinter.printLine();
                                    }
                                    total_flujo += (flujo.getTipo_cambio() * flujo.getImporte());
                                }

                                if (index_documento + 1 == documentos.size() || documento.getSocio_id() != documentos.get(index_documento + 1).getSocio_id()) {
                                    mPrinter.setBold(true);
                                    mPrinter.printText(String.format("--->  TOTAL (%s)   %s", socio.getCodigo(), Functions.toCurrency(total_flujo)));
                                    mPrinter.addNewLine();
                                    mPrinter.printLine();
                                    mPrinter.setBold(false);

                                    total_flujo = 0.0;
                                }
                            }

                            index_documento++;
                        }
                    } catch (Exception ex) {
                        mPrinter.printText(String.format("Error al obtener el flujo %s", ex.getMessage()));
                        mPrinter.addNewLine();
                    }

                    mPrinter.feedPaper();
                    mPrinter.finish();
                }

                @Override
                public void onFailed() {
                    Log.d("BluetoothPrinter", "Conexión fallida");
                }
            });
        } catch (Exception ex) {
            Log.d("BluetoothPrinter", ex.getMessage());
        }
    }

    public void ImprimirDocumentos()
    {
        try {
            final BluetoothPrinter mPrinter = new BluetoothPrinter(mBtDevice);
            mPrinter.connectPrinter(new BluetoothPrinter.PrinterConnectListener() {
                @Override
                public void onConnected() {
                    Empresa empresa = Empresa.Obtener();

                    mPrinter.setAlign(BluetoothPrinter.ALIGN_CENTER);

                    mPrinter.addNewLine();
                    mPrinter.printText(empresa.getNombre_fiscal());
                    mPrinter.addNewLine();

                    mPrinter.setAlign(BluetoothPrinter.ALIGN_LEFT);

                    mPrinter.printText("R.F.C. " + empresa.getRfc());
                    mPrinter.addNewLine();

                    mPrinter.printText("Tel. " + empresa.getTelefono());
                    mPrinter.addNewLine();

                    mPrinter.setAlign(BluetoothPrinter.ALIGN_CENTER);

                    mPrinter.printText("--------------------------");
                    mPrinter.addNewLine();

                    mPrinter.setBold(true);
                    mPrinter.printText("DOCUMENTOS");
                    mPrinter.addNewLine();
                    mPrinter.setBold(false);

                    mPrinter.setAlign(BluetoothPrinter.ALIGN_LEFT);

                    mPrinter.setBold(true);
                    mPrinter.printText("CLIENTE");
                    mPrinter.addNewLine();
                    mPrinter.printText("DOCUMENTO    APLICADO      TOTAL");
                    mPrinter.addNewLine();
                    mPrinter.setBold(false);

                    try {
                        List<Documento> documentos = Documento.Documentos().queryBuilder().orderBy("socio_id", false).where().eq("clase", "EN").and().rawComparison("fecha_documento", ">=", Functions.getCurrentDate()).and().rawComparison("importe_aplicado", ">", 0).query();

                        for (Documento documento : documentos) {
                            Socio socio = Socio.Obtener(documento.getSocio_id());
                            if (socio != null) {
                                mPrinter.printText(socio.getNombre());
                                mPrinter.addNewLine();

                                mPrinter.printText(String.format("%s    %s      %s", documento.getId().toString(), Functions.toCurrency(documento.getImporte_aplicado()), Functions.toCurrency(documento.getTotal())));
                                mPrinter.addNewLine();
                                mPrinter.printLine();
                            }
                        }
                    } catch (Exception ex) {
                        mPrinter.printText(String.format("Error al obtener el flujo %s", ex.getMessage()));
                        mPrinter.addNewLine();
                    }

                    mPrinter.feedPaper();
                    mPrinter.finish();
                }

                @Override
                public void onFailed() {
                    Log.d("BluetoothPrinter", "Conexión fallida");
                }
            });
        } catch (Exception ex) {
            Log.d("BluetoothPrinter", ex.getMessage());
        }
    }

    public void Prueba() {
        final BluetoothPrinter mPrinter = new BluetoothPrinter(mBtDevice);
        mPrinter.connectPrinter(new BluetoothPrinter.PrinterConnectListener() {
            @Override
            public void onConnected() {
                mPrinter.setAlign(BluetoothPrinter.ALIGN_CENTER);
                mPrinter.printText("Conexión realizada correctamente");
                mPrinter.addNewLine();

                mPrinter.finish();
            }

            @Override
            public void onFailed() {
                Log.d("BluetoothPrinter", "Conexión fallida");
            }
        });
    }
}
