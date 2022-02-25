package mx.nori.nori.NoriSDK;

import android.app.Application;

public class Global extends Application {
    private static Configuracion configuracion;
    private static Usuario usuario;
    private static Integer estacion_id;
    private static String imei;
    private static Boolean sincronizando = false;
    private static Exception error = new Exception("Error desconocido");

    public static void Inicilizar()
    {
        configuracion = Configuracion.Obtener();
        usuario = Usuario.Obtener();
    }

    public static Configuracion getConfiguracion() {
        return configuracion;
    }

    public static Usuario getUsuario() {
        return usuario;
    }

    public static Integer getEstacion_id() {
        return 1;
    }

    public static void setEstacion_id(Integer estacion_id) {
        Global.estacion_id = estacion_id;
    }

    public static String getIMEI() {
        return imei;
    }

    public static void setIMEI(String imei) {
        Global.imei = imei;
    }

    public static Boolean getSincronizando() {
        return sincronizando;
    }

    public static void setSincronizando(Boolean sincronizando) {
        Global.sincronizando = sincronizando;
    }

    public static Exception getError() {
        return error;
    }

    public static void setError(Exception error) {
        Global.error = error;
    }
}
