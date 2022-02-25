package mx.nori.nori;

import android.app.Application;
import android.content.Context;

public class Nori extends Application {
    private static Context context;
    public static String estado = "";

    @Override
    public void onCreate() {
        super.onCreate();
        context = getApplicationContext();
    }

    public static Context getContext() {
        return context;
    }
}