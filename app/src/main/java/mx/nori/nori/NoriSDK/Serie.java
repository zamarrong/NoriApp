package mx.nori.nori.NoriSDK;

import com.google.gson.annotations.Expose;
import com.google.gson.annotations.SerializedName;
import com.j256.ormlite.dao.Dao;
import com.j256.ormlite.field.DatabaseField;
import com.j256.ormlite.table.DatabaseTable;

import java.util.Date;
import java.util.List;

import mx.nori.nori.Functions;
import mx.nori.nori.MainActivity;
import retrofit2.Call;
import retrofit2.Callback;
import retrofit2.Response;

@DatabaseTable(tableName = "series")
public class Serie {
    @DatabaseField(columnName = "id", id = true, unique = true)
    @SerializedName("id")
    @Expose
    private Integer id;

    @DatabaseField(columnName = "clase")
    @SerializedName("clase")
    @Expose
    private String clase;

    @DatabaseField(columnName = "codigo")
    @SerializedName("codigo")
    @Expose
    private Short codigo;

    @DatabaseField(columnName = "nombre")
    @SerializedName("nombre")
    @Expose
    private String nombre;

    @DatabaseField(columnName = "prefijo")
    @SerializedName("prefijo")
    @Expose
    private String prefijo;

    @DatabaseField(columnName = "subfijo")
    @SerializedName("subfijo")
    @Expose
    private String subfijo;

    @DatabaseField(columnName = "inicial")
    @SerializedName("inicial")
    @Expose
    private Integer inicial;

    @DatabaseField(columnName = "siguiente")
    @SerializedName("siguiente")
    @Expose
    private Integer siguiente;

    @DatabaseField(columnName = "predeterminado")
    @SerializedName("predeterminado")
    @Expose
    private Boolean predeterminado;

    @DatabaseField(columnName = "activo")
    @SerializedName("activo")
    @Expose
    private Boolean activo;

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

    public static Dao Series()
    {
        try {
            return MainActivity.db.Series();
        } catch (Exception ex) {
            return null;
        }
    }

    public Serie()
    {
        fecha_creacion = Functions.getCurrentDateTime();
        fecha_actualizacion = Functions.getCurrentDateTime();
    }

    public Boolean Agregar()
    {
        try {
            Series().create(this);
            return true;
        }
        catch (Exception ex) {
            Global.setError(ex);
            return false;
        }
    }

    public static Serie Obtener(Integer id)
    {
        try
        {
            return (Serie) Series().queryForId(id);
        } catch (Exception ex) {
            Global.setError(ex);
            return null;
        }
    }

    public static Serie Obtener(Short codigo)
    {
        try
        {
            return (Serie) Series().queryBuilder().where().eq("codigo", codigo).queryForFirst();
        } catch (Exception ex) {
            Global.setError(ex);
            return null;
        }
    }

    public static Serie ObtenerPredeterminado(String clase)
    {
        try
        {
            return (Serie) Series().queryBuilder().where().eq("clase", clase).and().eq("predeterminado", true).and().eq("activo", true).queryForFirst();
        } catch (Exception ex) {
            Global.setError(ex);
            return null;
        }
    }

    public static List<Serie> ObtenerSeriesPorDocumento(String clase)
    {
        try
        {
            return (List<Serie>) Series().queryBuilder().where().eq("clase", clase).and().eq("activo", true).query();
        } catch (Exception ex) {
            Global.setError(ex);
            return null;
        }
    }

    public Boolean EstablecerSiguiente()
    {
        try {
            usuario_actualizacion_id = Global.getUsuario().getId();
            fecha_actualizacion = Functions.getCurrentDateTime();
            siguiente += 1;
            Series().update(this);
            return true;
        }
        catch (Exception ex) {
            Global.setError(ex);
            return false;
        }
    }

    public static List<Serie> Listar()
    {
        try {
            return (List<Serie>) Series().queryForAll();
        }
        catch (Exception ex) {
            Global.setError(ex);
            return null;
        }
    }

    public Boolean Actualizar()
    {
        try {
            usuario_actualizacion_id = Global.getUsuario().getId();
            fecha_actualizacion = Functions.getCurrentDateTime();
            Series().update(this);
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
            List<Serie> series = MainActivity.api.series().execute().body();
            for (Serie serie : series) {
                try {
                    if (Serie.Obtener(serie.id) == null) {
                        serie.Agregar();
                    } else {
                        serie.Actualizar();
                    }
                } catch (Exception ex) {
                    Global.setError(ex);
                    continue;
                }
            }
        } catch (Exception ex) {
            Global.setError(ex);
        } finally {
            Global.setSincronizando(false);
        }
    }

    public static void SincronizarAsync()
    {
        MainActivity.api.series().enqueue(new Callback<List<Serie>>() {
            @Override
            public void onResponse(Call<List<Serie>> call, Response<List<Serie>> response) {
                if(response.isSuccessful()) {
                    List<Serie> series = response.body();
                    for (Serie serie : series) {
                        try {
                            if (Serie.Obtener(serie.id) == null) {
                                serie.Agregar();
                            } else {
                                serie.Actualizar();
                            }
                        } catch (Exception ex) {
                            Global.setError(ex);
                            continue;
                        }
                    }
                }
            }

            @Override
            public void onFailure(Call<List<Serie>> call, Throwable t) {
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

    public String getClase() {
        return clase;
    }

    public void setClase(String clase) {
        this.clase = clase;
    }

    public Short getCodigo() {
        return codigo;
    }

    public void setCodigo(Short codigo) {
        this.codigo = codigo;
    }

    public String getNombre() {
        return nombre;
    }

    public void setNombre(String nombre) {
        this.nombre = nombre;
    }

    public String getPrefijo() {
        return prefijo;
    }

    public void setPrefijo(String prefijo) {
        this.prefijo = prefijo;
    }

    public String getSubfijo() {
        return subfijo;
    }

    public void setSubfijo(String subfijo) {
        this.subfijo = subfijo;
    }

    public Integer getInicial() {
        return inicial;
    }

    public void setInicial(Integer inicial) {
        this.inicial = inicial;
    }

    public Integer getSiguiente() {
        return siguiente;
    }

    public void setSiguiente(Integer siguiente) {
        this.siguiente = siguiente;
    }

    public Boolean getPredeterminado() {
        return predeterminado;
    }

    public void setPredeterminado(Boolean predeterminado) {
        this.predeterminado = predeterminado;
    }

    public Boolean getActivo() {
        return activo;
    }

    public void setActivo(Boolean activo) {
        this.activo = activo;
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
}