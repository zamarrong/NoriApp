package mx.nori.nori.NoriSDK;

import android.content.Context;
import android.os.Handler;
import android.os.Looper;
import android.widget.Toast;

import mx.nori.nori.Functions;
import mx.nori.nori.Nori;
import mx.nori.nori.documentos.documento.DocumentoActivity;
import okio.Timeout;

public class Sincronizacion {
    public static void SincronizarGeneral()
    {
        new Thread(new Runnable() {
            public void run() {
                FechaSincronizacion fechaSincronizacion = FechaSincronizacion.Obtener("general");

                Configuracion.Sincronizar();
                Empresa.Sincronizar();
                Usuario.Sincronizar();
                if (Global.getUsuario() != null) {
                    Almacen.Sincronizar();
                    GrupoArticulo.Sincronizar();
                    UnidadMedida.Sincronizar();
                    GrupoSocio.Sincronizar();
                    Moneda.Sincronizar();
                    TipoCambio.Sincronizar(Functions.toDateTimeString(fechaSincronizacion.getFecha()));
                    Impuesto.Sincronizar();
                    ListaPrecio.Sincronizar();
                    CondicionesPago.Sincronizar();
                    MetodoPago.Sincronizar();
                    MetodoPago.Tipo.Sincronizar();
                    Fabricante.Sincronizar();
                    Estado.Sincronizar();
                    Pais.Sincronizar();
                    Vendedor.Sincronizar();
                    Serie.Sincronizar();
                    Actividad.Tipo.Sincronizar();
                    Causalidad.Sincronizar();
                    Ruta.Sincronizar();

                    fechaSincronizacion.Actualizar();
                }
                new Handler(Looper.getMainLooper()).post(new Runnable() {
                    public void run() {
                        if (Global.getUsuario() == null) {
                            Toast.makeText(Nori.getContext(), "La sincronización no pudo continuar, no se ha asignado usuario al dispositivo.", Toast.LENGTH_LONG).show();
                            Global.setSincronizando(false);
                        } else {
                            Toast.makeText(Nori.getContext(), "Finalizó la sincronización general.", Toast.LENGTH_LONG).show();
                        }
                    }
                });
                try {
                    synchronized (this) {
                        wait(60000);
                    }
                } catch (InterruptedException e) {
                    e.printStackTrace();
                }
            }
        }).start();
    }

    public static void SincronizarArticulos() {
        new Thread(new Runnable() {
            public void run() {
                Articulo.ArticuloAPI.Sincronizar(Functions.toDateTimeString(FechaSincronizacion.Obtener("articulos").getFecha()));
                new Handler(Looper.getMainLooper()).post(new Runnable() {
                    public void run() {
                        Toast.makeText(Nori.getContext(), "Finalizó la sincronización de artículos.", Toast.LENGTH_LONG).show();
                    }
                });
                try {
                    synchronized (this) {
                        wait(6000000);
                    }
                } catch (InterruptedException e) {
                    e.printStackTrace();
                }
            }
        }).start();
    }

    public static void SincronizarSocios() {
        new Thread(new Runnable() {
            public void run() {
                Socio.Sincronizar(Functions.toDateTimeString(FechaSincronizacion.Obtener("socios").getFecha()));
                new Handler(Looper.getMainLooper()).post(new Runnable() {
                    public void run() {
                        Toast.makeText(Nori.getContext(), "Finalizó la sincronización de socios.", Toast.LENGTH_LONG).show();
                    }
                });
                try {
                    synchronized (this) {
                        wait(60000);
                    }
                } catch (InterruptedException e) {
                    e.printStackTrace();
                }
            }
        }).start();
    }

    public static void SincronizarDocumentos() {
        new Thread(new Runnable() {
            public void run() {
                Documento.Sincronizar();
                new Handler(Looper.getMainLooper()).post(new Runnable() {
                    public void run() {
                        Toast.makeText(Nori.getContext(), "Finalizó la sincronización de documentos.", Toast.LENGTH_LONG).show();
                    }
                });
                try {
                    synchronized (this) {
                        wait(60000);
                    }
                } catch (InterruptedException e) {
                    e.printStackTrace();
                }
            }
        }).start();
    }

    public static void SincronizarActividades() {
        new Thread(new Runnable() {
            public void run() {
                Actividad.Sincronizar();
                new Handler(Looper.getMainLooper()).post(new Runnable() {
                    public void run() {
                        Toast.makeText(Nori.getContext(), "Finalizó la sincronización de actividades.", Toast.LENGTH_LONG).show();
                    }
                });
                try {
                    synchronized (this) {
                        wait(60000);
                    }
                } catch (InterruptedException e) {
                    e.printStackTrace();
                }
            }
        }).start();
    }
}
