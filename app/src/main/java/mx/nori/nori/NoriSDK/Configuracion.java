package mx.nori.nori.NoriSDK;

import com.google.gson.annotations.Expose;
import com.google.gson.annotations.SerializedName;
import com.j256.ormlite.dao.Dao;
import com.j256.ormlite.field.DatabaseField;
import com.j256.ormlite.table.DatabaseTable;

import java.util.Date;

import mx.nori.nori.Functions;
import mx.nori.nori.MainActivity;
import retrofit2.Call;
import retrofit2.Callback;
import retrofit2.Response;

@DatabaseTable(tableName = "configuracion")
public class Configuracion {
    @DatabaseField(columnName = "id", id = true, unique = true)
    @SerializedName("id")
    @Expose
    private Integer id;

    @DatabaseField(columnName = "tipo_metodo_pago_monedero_id")
    @SerializedName("tipo_metodo_pago_monedero_id")
    @Expose
    private Integer tipo_metodo_pago_monedero_id;

    @DatabaseField(columnName = "condicion_pago_id")
    @SerializedName("condicion_pago_id")
    @Expose
    private Integer condicion_pago_id;

    @DatabaseField(columnName = "metodo_pago_id")
    @SerializedName("metodo_pago_id")
    @Expose
    private Integer metodo_pago_id;

    @DatabaseField(columnName = "departamento_id")
    @SerializedName("departamnto_id")
    @Expose
    private Integer departamento_id;

    @DatabaseField(columnName = "fabricante_id")
    @SerializedName("fabricante_id")
    @Expose
    private Integer fabricante_id;

    @DatabaseField(columnName = "grupo_articulo_id")
    @SerializedName("grupo_articulo_id")
    @Expose
    private Integer grupo_articulo_id;

    @DatabaseField(columnName = "impuesto_id")
    @SerializedName("impuesto_id")
    @Expose
    private Integer impuesto_id;

    @DatabaseField(columnName = "lista_precio_id")
    @SerializedName("lista_precio_id")
    @Expose
    private Integer lista_precio_id;

    @DatabaseField(columnName = "moneda_id")
    @SerializedName("moneda_id")
    @Expose
    private Integer moneda_id;

    @DatabaseField(columnName = "unidad_medida_id")
    @SerializedName("unidad_medida_id")
    @Expose
    private Integer unidad_medida_id;

    @DatabaseField(columnName = "zona_id")
    @SerializedName("zona_id")
    @Expose
    private Integer zona_id;

    @DatabaseField(columnName = "api_url")
    @SerializedName("api_url")
    @Expose
    private String api_url;

    @DatabaseField(columnName = "modo_rapido")
    @SerializedName("modo_rapido")
    @Expose
    private boolean modo_rapido;

    @DatabaseField(columnName = "modo_vivo")
    @SerializedName("modo_vivo")
    @Expose
    private boolean modo_vivo;

    @DatabaseField(columnName = "fecha_creacion")
    private transient Date fecha_creacion;

    @DatabaseField(columnName = "usuario_actualizacion_id")
    @SerializedName("usuario_actualizacion_id")
    @Expose
    private Integer usuario_actualizacion_id;

    @DatabaseField(columnName = "fecha_actualizacion")
    private transient Date fecha_actualizacion;

    public static Dao Configuracion()
    {
        try {
            return MainActivity.db.Configuracion();
        } catch (Exception ex) {
            return null;
        }
    }

    public Configuracion()
    {
        try {
            modo_rapido = false;
            modo_vivo = false;
            fecha_creacion = Functions.getCurrentDateTime();
            fecha_actualizacion = Functions.getCurrentDateTime();
        } catch (Exception ex) {
            Global.setError(ex);
        }
    }

    public Boolean Agregar()
    {
        try {
            Configuracion().create(this);

            FechaSincronizacion fechaSincronizacion = new FechaSincronizacion();

            fechaSincronizacion.setTabla("general");
            fechaSincronizacion.Agregar();

            fechaSincronizacion.setTabla("socios");
            fechaSincronizacion.Agregar();

            fechaSincronizacion.setTabla("articulos");
            fechaSincronizacion.Agregar();

            fechaSincronizacion.setTabla("documentos");
            fechaSincronizacion.Agregar();

            Sincronizar();
            return true;
        }
        catch (Exception ex) {
            Global.setError(ex);
            return false;
        }
    }

    public static Configuracion Obtener()
    {
        try
        {
            return (Configuracion) Configuracion().queryForId(1);
        } catch (Exception ex) {
            Global.setError(ex);
            return null;
        }
    }

    public Boolean Actualizar()
    {
        try {
            fecha_actualizacion = Functions.getCurrentDateTime();
            Configuracion().update(this);
            return true;
        }
        catch (Exception ex) {
            Global.setError(ex);
            return false;
        }
    }

    public static void Sincronizar()
    {
        try {
            Configuracion configuracion =  MainActivity.api.configuracion().execute().body();
            try {
                if (Configuracion.Obtener() == null) {
                    configuracion.Agregar();
                } else {
                    configuracion.Actualizar();
                }
            } catch (Exception ex) {
                Global.setError(ex);
            }
        } catch (Exception ex) {
            Global.setError(ex);
        }
    }

    public static void SincronizarAsync()
    {
        MainActivity.api.configuracion().enqueue(new Callback<Configuracion>() {
            @Override
            public void onResponse(Call<Configuracion> call, Response<Configuracion> response) {
                if(response.isSuccessful()) {
                    Configuracion configuracion = response.body();
                    try {
                        if (Configuracion.Obtener() == null) {
                            configuracion.Agregar();
                        } else {
                            configuracion.Actualizar();
                        }
                    } catch (Exception ex) {
                        Global.setError(ex);
                    }
                }
            }

            @Override
            public void onFailure(Call<Configuracion> call, Throwable t) {
                //
            }
        });
    }

    public Integer getId() {
        return id;
    }

    public void setId(Integer id) {
        this.id = id;
    }

    public Integer getTipo_metodo_pago_monedero_id() {
        return tipo_metodo_pago_monedero_id;
    }

    public void setTipo_metodo_pago_monedero_id(Integer tipo_metodo_pago_monedero_id) {
        this.tipo_metodo_pago_monedero_id = tipo_metodo_pago_monedero_id;
    }

    public Integer getCondicion_pago_id() {
        return condicion_pago_id;
    }

    public void setCondicion_pago_id(Integer condicion_pago_id) {
        this.condicion_pago_id = condicion_pago_id;
    }

    public Integer getMetodo_pago_id() {
        return metodo_pago_id;
    }

    public void setMetodo_pago_id(Integer metodo_pago_id) {
        this.metodo_pago_id = metodo_pago_id;
    }

    public Integer getDepartamento_id() {
        return departamento_id;
    }

    public void setDepartamento_id(Integer departamento_id) {
        this.departamento_id = departamento_id;
    }

    public Integer getFabricante_id() {
        return fabricante_id;
    }

    public void setFabricante_id(Integer fabricante_id) {
        this.fabricante_id = fabricante_id;
    }

    public Integer getGrupo_articulo_id() {
        return grupo_articulo_id;
    }

    public void setGrupo_articulo_id(Integer grupo_articulo_id) {
        this.grupo_articulo_id = grupo_articulo_id;
    }

    public Integer getImpuesto_id() {
        return impuesto_id;
    }

    public void setImpuesto_id(Integer impuesto_id) {
        this.impuesto_id = impuesto_id;
    }

    public Integer getLista_precio_id() {
        return lista_precio_id;
    }

    public void setLista_precio_id(Integer lista_precio_id) {
        this.lista_precio_id = lista_precio_id;
    }

    public Integer getMoneda_id() {
        return moneda_id;
    }

    public void setMoneda_id(Integer moneda_id) {
        this.moneda_id = moneda_id;
    }

    public Integer getUnidad_medida_id() {
        return unidad_medida_id;
    }

    public void setUnidad_medida_id(Integer unidad_medida_id) {
        this.unidad_medida_id = unidad_medida_id;
    }

    public Integer getZona_id() {
        return zona_id;
    }

    public void setZona_id(Integer zona_id) {
        this.zona_id = zona_id;
    }

    public String getApi_url() {
        return api_url;
    }

    public void setApi_url(String api_url) {
        this.api_url = api_url;
    }

    public boolean getModo_rapido() {
        return modo_rapido;
    }

    public void setModo_rapido(boolean modo_rapido) {
        this.modo_rapido = modo_rapido;
    }

    public boolean getModo_vivo() {
        return modo_vivo;
    }

    public void setModo_vivo(boolean modo_vivo) {
        this.modo_vivo = modo_vivo;
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
}