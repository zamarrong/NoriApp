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

@DatabaseTable(tableName = "fabricantes")
public class Fabricante {
    @DatabaseField(columnName = "id", id = true, unique = true)
    @SerializedName("id")
    @Expose
    private Integer id;

    @DatabaseField(columnName = "codigo")
    @SerializedName("codigo")
    @Expose
    private Short codigo;

    @DatabaseField(columnName = "nombre")
    @SerializedName("nombre")
    @Expose
    private String nombre;

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

    public static Dao Fabricantes()
    {
        try {
            return MainActivity.db.Fabricantes();
        } catch (Exception ex) {
            return null;
        }
    }

    public Fabricante()
    {
        fecha_creacion = Functions.getCurrentDateTime();
        fecha_actualizacion = Functions.getCurrentDateTime();
    }

    public Boolean Agregar()
    {
        try {
            Fabricantes().create(this);
            return true;
        }
        catch (Exception ex) {
            Global.setError(ex);
            return false;
        }
    }

    public static Fabricante Obtener(Integer id)
    {
        try
        {
            return (Fabricante) Fabricantes().queryForId(id);
        } catch (Exception ex) {
            Global.setError(ex);
            return null;
        }
    }

    public static Fabricante Obtener(Short codigo)
    {
        try
        {
            return (Fabricante) Fabricantes().queryBuilder().where().eq("codigo", codigo).queryForFirst();
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
            Fabricantes().update(this);
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
            List<Fabricante> fabricantes = MainActivity.api.fabricantes().execute().body();
            for (Fabricante fabricante : fabricantes) {
                try {
                    if (Fabricante.Obtener(fabricante.id) == null) {
                        fabricante.Agregar();
                    } else {
                        fabricante.Actualizar();
                    }
                } catch (Exception ex) {
                    Global.setError(ex);
                    continue;
                }
            }
        } catch (Exception ex) {
            Global.setError(ex);
        }
    }

    public static void SincronizarAsync()
    {
        MainActivity.api.fabricantes().enqueue(new Callback<List<Fabricante>>() {
            @Override
            public void onResponse(Call<List<Fabricante>> call, Response<List<Fabricante>> response) {
                if(response.isSuccessful()) {
                    List<Fabricante> fabricantes = response.body();
                    for (Fabricante fabricante : fabricantes) {
                        try {
                            if (Fabricante.Obtener(fabricante.id) == null) {
                                fabricante.Agregar();
                            } else {
                                fabricante.Actualizar();
                            }
                        } catch (Exception ex) {
                            Global.setError(ex);
                            continue;
                        }
                    }
                }
            }

            @Override
            public void onFailure(Call<List<Fabricante>> call, Throwable t) {
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