package mx.nori.nori;

import android.Manifest;
import android.app.AlertDialog;
import android.app.FragmentTransaction;
import android.content.Context;
import android.content.DialogInterface;
import android.content.pm.PackageManager;
import android.os.Bundle;
import android.support.design.widget.FloatingActionButton;
import android.support.design.widget.Snackbar;
import android.app.FragmentManager;
import android.support.v4.app.ActivityCompat;
import android.telephony.TelephonyManager;
import android.view.View;
import android.support.design.widget.NavigationView;
import android.support.v4.view.GravityCompat;
import android.support.v4.widget.DrawerLayout;
import android.support.v7.app.ActionBarDrawerToggle;
import android.support.v7.app.AppCompatActivity;
import android.support.v7.widget.Toolbar;
import android.view.Menu;
import android.view.MenuItem;
import android.widget.EditText;
import android.widget.Toast;

import com.google.gson.Gson;
import com.google.gson.GsonBuilder;
import com.j256.ormlite.android.apptools.OpenHelperManager;
import java.util.List;
import java.util.concurrent.TimeUnit;

import mx.nori.nori.NoriSDK.Actividad;
import mx.nori.nori.NoriSDK.Almacen;
import mx.nori.nori.NoriSDK.Articulo;
import mx.nori.nori.NoriSDK.Causalidad;
import mx.nori.nori.NoriSDK.CondicionesPago;
import mx.nori.nori.NoriSDK.Configuracion;
import mx.nori.nori.NoriSDK.DB;
import mx.nori.nori.NoriSDK.Documento;
import mx.nori.nori.NoriSDK.Empresa;
import mx.nori.nori.NoriSDK.Estado;
import mx.nori.nori.NoriSDK.Fabricante;
import mx.nori.nori.NoriSDK.Flujo;
import mx.nori.nori.NoriSDK.Global;
import mx.nori.nori.NoriSDK.GrupoArticulo;
import mx.nori.nori.NoriSDK.GrupoSocio;
import mx.nori.nori.NoriSDK.Impuesto;
import mx.nori.nori.NoriSDK.ListaPrecio;
import mx.nori.nori.NoriSDK.MetodoPago;
import mx.nori.nori.NoriSDK.Moneda;
import mx.nori.nori.NoriSDK.Pais;
import mx.nori.nori.NoriSDK.Ruta;
import mx.nori.nori.NoriSDK.Serie;
import mx.nori.nori.NoriSDK.Sincronizacion;
import mx.nori.nori.NoriSDK.Socio;
import mx.nori.nori.NoriSDK.TipoCambio;
import mx.nori.nori.NoriSDK.UnidadMedida;
import mx.nori.nori.NoriSDK.Usuario;
import mx.nori.nori.NoriSDK.Vendedor;
import mx.nori.nori.actividad.ActividadesFragment;
import mx.nori.nori.articulos.ArticulosFragment;
import mx.nori.nori.documentos.DocumentosFragment;
import mx.nori.nori.mas.ConfiguracionFragment;
import mx.nori.nori.ruta.MapaFragment;
import mx.nori.nori.ruta.RutaFragment;
import mx.nori.nori.socios.SociosFragment;
import okhttp3.OkHttpClient;
import retrofit2.Call;
import retrofit2.Retrofit;
import retrofit2.converter.gson.GsonConverterFactory;
import retrofit2.http.Body;
import retrofit2.http.GET;
import retrofit2.http.POST;
import retrofit2.http.Path;
import retrofit2.http.Query;

public class MainActivity extends AppCompatActivity implements NavigationView.OnNavigationItemSelectedListener {

    public Retrofit retrofit;
    public static NoriAPI api;
    public static DB db;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);
        Toolbar toolbar = findViewById(R.id.toolbar);
        setSupportActionBar(toolbar);

        Initialize();

        FloatingActionButton fab = findViewById(R.id.fabSincronizar);
        fab.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                if (!Synchronizing()) {
                    if (Global.getUsuario() != null) {
                        Snackbar.make(view, "Sincronizando...", Snackbar.LENGTH_LONG).setAction("Action", null).show();
                        Sincronizacion.SincronizarDocumentos();
                        Sincronizacion.SincronizarActividades();
                    } else {
                        Toast.makeText(view.getContext(), "Aún no se ha establecido un usuario.", Toast.LENGTH_SHORT).show();
                    }
                }
            }
        });

        DrawerLayout drawer = findViewById(R.id.drawer_layout);
        ActionBarDrawerToggle toggle = new ActionBarDrawerToggle(this, drawer, toolbar, R.string.navigation_drawer_open, R.string.navigation_drawer_close);
        drawer.addDrawerListener(toggle);
        toggle.syncState();

        NavigationView navigationView = findViewById(R.id.nav_view);
        navigationView.setNavigationItemSelectedListener(this);

        setFragment("principal");
    }

    @Override
    public void onBackPressed() {
        DrawerLayout drawer = findViewById(R.id.drawer_layout);
        if (drawer.isDrawerOpen(GravityCompat.START)) {
            drawer.closeDrawer(GravityCompat.START);
        } else {
            super.onBackPressed();
        }
    }

    @Override
    public boolean onCreateOptionsMenu(Menu menu) {
        // Inflate the menu; this adds items to the action bar if it is present.
        getMenuInflater().inflate(R.menu.main, menu);
        return true;
    }

    @Override
    public boolean onOptionsItemSelected(MenuItem item) {
        switch (item.getItemId()) {
            case R.id.action_api_url:
                setAPIURL();
                return  true;
            case R.id.action_get_deviceID:
                Toast.makeText(this, Global.getIMEI(), Toast.LENGTH_LONG).show();
                return  true;
        }
        return super.onOptionsItemSelected(item);
    }

    @SuppressWarnings("StatementWithEmptyBody")
    @Override
    public boolean onNavigationItemSelected(MenuItem item) {
        // Handle navigation view item clicks here.
        int id = item.getItemId();

        switch (id)
        {
            case R.id.nav_principal:
                setFragment("principal");
                break;
            //Ruta
            case R.id.nav_ruta:
                setFragment("ruta");
                break;
            case R.id.nav_actividades:
                setFragment("actividades");
                break;
            case R.id.nav_mapa:
                setFragment("mapa");
                break;
            //Ventas
            case R.id.nav_cotizaciones:
                setFragment("cotizaciones");
                break;
            case R.id.nav_pedidos:
                setFragment("pedidos");
                break;
            case R.id.nav_entregas:
                setFragment("entregas");
                break;
            case R.id.nav_devoluciones:
                setFragment("devoluciones");
                break;
            case R.id.nav_facturas:
                setFragment("facturas");
                break;
            case R.id.nav_notas_credito:
                setFragment("notas_credito");
                break;
            //Socios
            case R.id.nav_socios:
                setFragment("socios");
                break;
            //Inventario
            case R.id.nav_articulos:
                setFragment("articulos");
                break;
            case R.id.nav_solicitudes_traslado:
                setFragment("solicitudes_traslado");
                break;
            case R.id.nav_inventarios_fisicos:
                setFragment("inventarios_fisicos");
                break;
            //Informes
            case R.id.nav_informes_documentos:
                Impresora impresora_documentos = new Impresora();
                impresora_documentos.ImprimirDocumentos();
                break;
            case R.id.nav_informes_inventario:
                Impresora impresora_inventario = new Impresora();
                impresora_inventario.ImprimirInventario();
                break;
            case R.id.nav_informes_flujo:
                Impresora impresora_flujo = new Impresora();
                impresora_flujo.ImprimirFlujo();
                break;
            //Sincronizacion
            case R.id.nav_sincronizacion_general:
                if (!Synchronizing()) {
                    Sincronizacion.SincronizarGeneral();
                }
                break;
            case R.id.nav_sincronizacion_socios:
                if (!Synchronizing()) {
                    if (Global.getUsuario() != null) {
                        Sincronizacion.SincronizarSocios();
                    } else {
                        Toast.makeText(this, "Aún no se ha establecido un usuario.", Toast.LENGTH_SHORT).show();
                        Global.setSincronizando(false);
                    }
                }
                break;
            case R.id.nav_sincronizacion_articulos:
                if (!Synchronizing()) {
                    if (Global.getUsuario() != null) {
                        Sincronizacion.SincronizarArticulos();
                    } else {
                        Toast.makeText(this, "Aún no se ha establecido un usuario.", Toast.LENGTH_SHORT).show();
                        Global.setSincronizando(false);
                    }
                }
                break;
            //Más
            case R.id.nav_configuracion:
                setFragment("configuracion");
                break;
        }

        DrawerLayout drawer = findViewById(R.id.drawer_layout);
        drawer.closeDrawer(GravityCompat.START);
        return true;
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        if (db != null) {
            OpenHelperManager.releaseHelper();
            db = null;
        }
    }

    public interface NoriAPI {
        //General
        @GET("configuracion")
        Call<Configuracion> configuracion();
        @GET("empresa")
        Call<Empresa> empresa();
        @GET("usuarios")
        Call<List<Usuario>> usuarios();
        @GET("usuarios/{id}/listas-precios")
        Call<List<Usuario.ListaPrecio>> usuarios_listas_precios(@Path("id") Integer id);
        @GET("almacenes")
        Call<List<Almacen>> almacenes();
        @GET("almacenes/{id}/ubicaciones")
        Call<List<Almacen.Ubicacion>> almacenes_ubicaciones(@Path("id") Integer id);
        @GET("monedas")
        Call<List<Moneda>> monedas();
        @GET("tipos-cambio")
        Call<List<TipoCambio>> tipos_cambio(@Query("fecha") String fecha);
        @GET("impuestos")
        Call<List<Impuesto>> impuestos();
        @GET("listas-precios")
        Call<List<ListaPrecio>> listas_precios();
        @GET("metodos-pago")
        Call<List<MetodoPago>> metodos_pago();
        @GET("metodos-pago/tipos")
        Call<List<MetodoPago.Tipo>> tipos_metodos_pago();
        @GET("condiciones-pago")
        Call<List<CondicionesPago>> condiciones_pago();
        @GET("fabricantes")
        Call<List<Fabricante>> fabricantes();
        @GET("grupos-socios")
        Call<List<GrupoSocio>> grupos_socios();
        @GET("grupos-articulos")
        Call<List<GrupoArticulo>> grupos_articulos();
        @GET("unidades-medida")
        Call<List<UnidadMedida>> unidades_medida();
        @GET("paises")
        Call<List<Pais>> paises();
        @GET("estados")
        Call<List<Estado>> estados();
        @GET("vendedores")
        Call<List<Vendedor>> vendedores();
        @GET("series")
        Call<List<Serie>> series();
        @GET("actividades/tipos")
        Call<List<Actividad.Tipo>> tipos_actividades();
        @POST("actividades")
        Call<Actividad> actividad(@Body Actividad actividad);
        @GET("causalidades")
        Call<List<Causalidad>> causalidades();
        @GET("rutas")
        Call<List<Ruta>> rutas();
        //Socios
        @GET("socios/{id}")
        Call<Socio> socio(@Path("id") Integer id);
        @GET("socios/{id}/direcciones")
        Call<List<Socio.Direccion>> socios_direcciones(@Path("id") Integer id);
        @GET("socios/actualizados")
        Call<List<Socio>> socios(@Query("fecha") String fecha);
        //Articulos
        @GET("articulos/{id}")
        Call<Articulo> articulo(@Path("id") Integer id);
        @GET("articulos/{id}/precios")
        Call<List<Articulo.Precio>> articulo_precios(@Path("id") Integer id);
        @GET("articulos/{id}/inventario")
        Call<List<Articulo.Inventario>> articulo_inventario(@Path("id") Integer id, @Query("almacen_id") Integer almacen_id);
        @GET("articulos/inventario/ubicaciones/{id}")
        Call<List<Articulo.Inventario.Ubicacion>> inventario_ubicaciones(@Path("id") Integer id);
        @GET("articulos/{id}/codigos-barras")
        Call<List<Articulo.CodigoBarras>> articulo_codigos_barras(@Path("id") Integer id);
        @GET("articulos/actualizados")
        Call<List<Articulo>> articulos(@Query("fecha") String fecha);
        @GET("articulos/actualizados-api")
        Call<List<Articulo.ArticuloAPI>> articulos_api(@Query("fecha") String fecha);
        @GET("articulos/actualizados-api/almacen/{almacen_id}")
        Call<List<Articulo.ArticuloAPI>> articulos_api_almacen(@Path("almacen_id") Integer almacen_id, @Query("fecha") String fecha);
        @GET("articulos/actualizados-api/busqueda/{almacen_id}/{lista_precio_id}")
        Call<List<Articulo.ArticuloAPI>> articulos_api_busqueda(@Path("almacen_id") Integer almacen_id, @Path("lista_precio_id") Integer lista_precio_id, @Query("q") String q);
        //Documentos
        @GET("documentos/{id}")
        Call<Documento> documento(@Path("id") Integer id);
        @POST("documentos")
        Call<Documento> documento(@Body Documento documento);
        @GET("documentos/actualizados")
        Call<List<Documento>> documentos(@Query("fecha") String fecha);
        //Flujo
        @POST("flujo")
        Call<Flujo> flujo(@Body Flujo flujo);
    }

    public void Initialize()
    {
        try {
            db = OpenHelperManager.getHelper(this, DB.class);

            Global.setIMEI(getIMEI(this));
            Global.Inicilizar();

            if (Global.getConfiguracion() == null) {
                setAPIURL();
            }

            Gson gson = new GsonBuilder()
                    .setDateFormat("yyyy-MM-dd'T'HH:mm:ss")
                    .create();

            OkHttpClient.Builder client = new OkHttpClient.Builder();
            client.connectTimeout(900, TimeUnit.SECONDS);
            client.readTimeout(900, TimeUnit.SECONDS);
            client.writeTimeout(900, TimeUnit.SECONDS);

            retrofit = new Retrofit.Builder()
                    .baseUrl(Global.getConfiguracion().getApi_url())
                    .client(client.build())
                    .addConverterFactory(GsonConverterFactory.create(gson))
                    .build();

            api = retrofit.create(NoriAPI.class);

            if (Global.getConfiguracion() != null && Global.getUsuario() == null)
            {
                Usuario.Sincronizar();
            }

        } catch (Exception ex) {
            Toast.makeText(this, ex.getMessage(), Toast.LENGTH_LONG).show();
        }
    }

    public void setFragment(String fragment) {
        try
        {
            FragmentManager fragmentManager = getFragmentManager();
            FragmentTransaction fragmentTransaction = fragmentManager.beginTransaction();

            Bundle bundle = new Bundle();

            switch (fragment) {
                case "principal":
                    PrincipalFragment principalFragment = new PrincipalFragment();
                    fragmentTransaction.replace(R.id.fragment, principalFragment);
                    fragmentTransaction.commit();
                    break;
                //Ruta
                case "ruta":
                    RutaFragment rutaFragment = new RutaFragment();
                    fragmentTransaction.replace(R.id.fragment, rutaFragment);
                    fragmentTransaction.commit();
                    break;
                case "actividades":
                    ActividadesFragment actividadesFragment = new ActividadesFragment();
                    fragmentTransaction.replace(R.id.fragment, actividadesFragment);
                    fragmentTransaction.commit();
                    break;
                case "mapa":
                    MapaFragment mapaFragment = new MapaFragment();
                    fragmentTransaction.replace(R.id.fragment, mapaFragment);
                    fragmentTransaction.commit();
                    break;
                //Documentos
                case "cotizaciones":
                    DocumentosFragment cotizacionesFragment = new DocumentosFragment();
                    bundle.putString("clase", "CO");
                    cotizacionesFragment.setArguments(bundle);
                    fragmentTransaction.replace(R.id.fragment, cotizacionesFragment);
                    fragmentTransaction.commit();
                    break;
                case "pedidos":
                    DocumentosFragment pedidosFragment = new DocumentosFragment();
                    bundle.putString("clase", "PE");
                    pedidosFragment.setArguments(bundle);
                    fragmentTransaction.replace(R.id.fragment, pedidosFragment);
                    fragmentTransaction.commit();
                    break;
                case "entregas":
                    DocumentosFragment entregasFragment = new DocumentosFragment();
                    bundle.putString("clase", "EN");
                    entregasFragment.setArguments(bundle);
                    fragmentTransaction.replace(R.id.fragment, entregasFragment);
                    fragmentTransaction.commit();
                    break;
                case "devoluciones":
                    DocumentosFragment devolucionesFragment = new DocumentosFragment();
                    bundle.putString("clase", "DV");
                    devolucionesFragment.setArguments(bundle);
                    fragmentTransaction.replace(R.id.fragment, devolucionesFragment);
                    fragmentTransaction.commit();
                    break;
                case "facturas":
                    DocumentosFragment facturasFragment = new DocumentosFragment();
                    bundle.putString("clase", "FA");
                    facturasFragment.setArguments(bundle);
                    fragmentTransaction.replace(R.id.fragment, facturasFragment);
                    fragmentTransaction.commit();
                    break;
                case "notas_credito":
                    DocumentosFragment notasCreditoFragment = new DocumentosFragment();
                    bundle.putString("clase", "NC");
                    notasCreditoFragment.setArguments(bundle);
                    fragmentTransaction.replace(R.id.fragment, notasCreditoFragment);
                    fragmentTransaction.commit();
                    break;
                //Catálogos
                //Socios
                case "socios":
                    SociosFragment sociosFragment = new SociosFragment();
                    fragmentTransaction.replace(R.id.fragment, sociosFragment);
                    fragmentTransaction.commit();
                    break;
                //Inventario
                case "articulos":
                    ArticulosFragment articulosFragment = new ArticulosFragment();
                    fragmentTransaction.replace(R.id.fragment, articulosFragment);
                    fragmentTransaction.commit();
                    break;
                case "solicitudes_traslado":
                    DocumentosFragment solicitudesTrasladoFragment = new DocumentosFragment();
                    bundle.putString("clase", "ST");
                    solicitudesTrasladoFragment.setArguments(bundle);
                    fragmentTransaction.replace(R.id.fragment, solicitudesTrasladoFragment);
                    fragmentTransaction.commit();
                    break;
                case "inventarios_fisicos":
                    DocumentosFragment inventariosFisicosFragment = new DocumentosFragment();
                    bundle.putString("clase", "IF");
                    inventariosFisicosFragment.setArguments(bundle);
                    fragmentTransaction.replace(R.id.fragment, inventariosFisicosFragment);
                    fragmentTransaction.commit();
                    break;
                //Más
                case "configuracion":
                    ConfiguracionFragment configuracionFragment = new ConfiguracionFragment();
                    fragmentTransaction.replace(R.id.fragment, configuracionFragment);
                    fragmentTransaction.commit();
                    break;
            }
        } catch (Exception ex) {
            Toast.makeText(this, ex.getMessage(), Toast.LENGTH_LONG).show();
        }
    }

    public static String getIMEI(Context context) {
        try {
            TelephonyManager telephonyManager = (TelephonyManager) context.getSystemService(Context.TELEPHONY_SERVICE);
            if (ActivityCompat.checkSelfPermission(context, Manifest.permission.READ_PHONE_STATE) != PackageManager.PERMISSION_GRANTED) {
                return "SIN PERMISO";
            }
            String imei = telephonyManager.getDeviceId();
            if (imei != null && !imei.isEmpty()) {
                return imei;
            } else {
                return android.os.Build.SERIAL;
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
        return "ERROR";
    }

    public void setAPIURL()
    {
        AlertDialog.Builder builder = new AlertDialog.Builder(this);
        builder.setTitle("Ingresa la URL del servicio API");

        final EditText input = new EditText(this);
        if (Global.getConfiguracion() != null) {
            input.setText(Global.getConfiguracion().getApi_url());
        } else {
            input.setText("http://");
        }
        builder.setView(input);

        builder.setPositiveButton("OK", new DialogInterface.OnClickListener() {
            @Override
            public void onClick(DialogInterface dialog, int which) {
                Configuracion configuracion;

                if (Global.getConfiguracion() == null) {
                    configuracion = new Configuracion();
                    configuracion.setId(1);
                    configuracion.setApi_url(input.getText().toString());
                    configuracion.Agregar();
                } else {
                    configuracion = Global.getConfiguracion();
                    configuracion.setApi_url(input.getText().toString());
                    configuracion.Actualizar();
                }

                Initialize();
            }
        });
        builder.setNegativeButton("Cancelar", new DialogInterface.OnClickListener() {
            @Override
            public void onClick(DialogInterface dialog, int which) {
                dialog.cancel();
            }
        });

        builder.show();
    }

    public Boolean Synchronizing()
    {
        try {
            if (Global.getSincronizando()) {
                Toast.makeText(this, "Sincronizando, por favor espere... " + Nori.estado, Toast.LENGTH_LONG).show();
                return true;
            } else {
                Global.setSincronizando(true);
                Toast.makeText(this, "Sincronizando...", Toast.LENGTH_LONG).show();
                return false;
            }
        } catch (Exception ex) {
            return false;
        }
    }
}
