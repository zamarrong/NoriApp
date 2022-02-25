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

@DatabaseTable(tableName = "almacenes")
public class Almacen {
    @DatabaseField(columnName = "id", id = true, unique = true)
    @SerializedName("id")
    @Expose
    private Integer id;

    @DatabaseField(columnName = "codigo")
    @SerializedName("codigo")
    @Expose
    private String codigo;

    @DatabaseField(columnName = "nombre")
    @SerializedName("nombre")
    @Expose
    private String nombre;

    @DatabaseField(columnName = "ubicaciones")
    @SerializedName("ubicaciones")
    @Expose
    private Boolean ubicaciones;

    @DatabaseField(columnName = "ubicacion_id")
    @SerializedName("ubicacion_id")
    @Expose
    private Integer ubicacion_id;

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

    public static Dao Almacenes()
    {
        try {
            return MainActivity.db.Almacenes();
        } catch (Exception ex) {
            return null;
        }
    }

    public Almacen()
    {
        fecha_creacion = Functions.getCurrentDateTime();
        fecha_actualizacion = Functions.getCurrentDateTime();
    }

    public Boolean Agregar()
    {
        try {
            Almacenes().create(this);
            return true;
        }
        catch (Exception ex) {
            Global.setError(ex);
            return false;
        }
    }

    public static Almacen Obtener(Integer id)
    {
        try
        {
            return (Almacen) Almacenes().queryForId(id);
        } catch (Exception ex) {
            Global.setError(ex);
            return null;
        }
    }

    public static Almacen Obtener(String codigo)
    {
        try
        {
            return (Almacen) Almacenes().queryBuilder().where().eq("codigo", codigo).queryForFirst();
        } catch (Exception ex) {
            Global.setError(ex);
            return null;
        }
    }

    public static List<Almacen> Listar()
    {
        try {
            return (List<Almacen>) Almacenes().queryForAll();
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
            Almacenes().update(this);
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
            List<Almacen> almacenes = MainActivity.api.almacenes().execute().body();
            for (Almacen almacen : almacenes) {
                try {
                    if (Almacen.Obtener(almacen.id) == null) {
                        almacen.Agregar();
                    } else {
                        almacen.Actualizar();
                    }
                    if (almacen.ubicaciones)
                        Ubicacion.Sincronizar(almacen.id);
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
        MainActivity.api.almacenes().enqueue(new Callback<List<Almacen>>() {
            @Override
            public void onResponse(Call<List<Almacen>> call, Response<List<Almacen>> response) {
                if(response.isSuccessful()) {
                    List<Almacen> almacenes = response.body();
                    for (Almacen almacen : almacenes) {
                        try {
                            if (Almacen.Obtener(almacen.id) == null) {
                                almacen.Agregar();
                            } else {
                                almacen.Actualizar();
                            }
                        } catch (Exception ex) {
                            Global.setError(ex);
                            continue;
                        }
                    }
                }
            }

            @Override
            public void onFailure(Call<List<Almacen>> call, Throwable t) {
                //
            }
        });
    }

    @Override
    public String toString() {
        return nombre;
    }

    public Integer getId() {
        return id;
    }

    public void setId(Integer id) {
        this.id = id;
    }

    public String getCodigo() {
        return codigo;
    }

    public void setCodigo(String codigo) {
        this.codigo = codigo;
    }

    public String getNombre() {
        return nombre;
    }

    public void setNombre(String nombre) {
        this.nombre = nombre;
    }

    public Boolean getUbicaciones() {
        return ubicaciones;
    }

    public void setUbicaciones(Boolean ubicaciones) {
        this.ubicaciones = ubicaciones;
    }

    public Integer getUbicacion_id() {
        return ubicacion_id;
    }

    public void setUbicacion_id(Integer ubicacion_id) {
        this.ubicacion_id = ubicacion_id;
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

    @DatabaseTable(tableName = "ubicaciones")
    public static class Ubicacion {
        @DatabaseField(columnName = "id", id = true, unique = true)
        @SerializedName("id")
        @Expose
        private Integer id;

        @DatabaseField(columnName = "codigo")
        @SerializedName("codigo")
        @Expose
        private Integer codigo;

        @DatabaseField(columnName = "almacen_id")
        @SerializedName("almacen_id")
        @Expose
        private Integer almacen_id;

        @DatabaseField(columnName = "ubicacion")
        @SerializedName("ubicacion")
        @Expose
        private String ubicacion;

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

        public static Dao Ubicaciones() {
            try {
                return MainActivity.db.AlmacenesUbicaciones();
            } catch (Exception ex) {
                return null;
            }
        }

        public Ubicacion() {
            fecha_creacion = Functions.getCurrentDateTime();
            fecha_actualizacion = Functions.getCurrentDateTime();
        }

        public Boolean Agregar() {
            try {
                Ubicaciones().create(this);
                return true;
            } catch (Exception ex) {
                Global.setError(ex);
                return false;
            }
        }

        public static Ubicacion Obtener(Integer id) {
            try {
                return (Ubicacion) Ubicaciones().queryForId(id);
            } catch (Exception ex) {
                Global.setError(ex);
                return null;
            }
        }

        public static List<Ubicacion> ObtenerPorAlmacen(int almacen_id) {
            try {
                return (List<Ubicacion>) Ubicaciones().queryForEq("almacen_id", almacen_id);
            } catch (Exception ex) {
                Global.setError(ex);
                return null;
            }
        }

        public static List<Ubicacion> Listar() {
            try {
                return (List<Ubicacion>) Ubicaciones().queryForAll();
            } catch (Exception ex) {
                Global.setError(ex);
                return null;
            }
        }

        public Boolean Actualizar() {
            try {
                usuario_actualizacion_id = Global.getUsuario().getId();
                fecha_actualizacion = Functions.getCurrentDateTime();
                Ubicaciones().update(this);
                return true;
            } catch (Exception ex) {
                Global.setError(ex);
                return false;
            }
        }

        public static void Sincronizar(int id) {
            try {
                List<Ubicacion> ubicaciones = MainActivity.api.almacenes_ubicaciones(id).execute().body();
                for (Ubicacion ubicacion : ubicaciones) {
                    try {
                        if (Ubicacion.Obtener(ubicacion.id) == null) {
                            ubicacion.Agregar();
                        } else {
                            ubicacion.Actualizar();
                        }
                        Articulo.Inventario.Ubicacion.Sincronizar(ubicacion.id);
                    } catch (Exception ex) {
                        Global.setError(ex);
                        continue;
                    }
                }
            } catch (Exception ex) {
                Global.setError(ex);
            }
        }

        public static void SincronizarAsync(int id) {
            MainActivity.api.almacenes_ubicaciones(id).enqueue(new Callback<List<Ubicacion>>() {
                @Override
                public void onResponse(Call<List<Ubicacion>> call, Response<List<Ubicacion>> response) {
                    if (response.isSuccessful()) {
                        List<Ubicacion> ubicaciones = response.body();
                        for (Ubicacion ubicacion : ubicaciones) {
                            try {
                                if (Ubicacion.Obtener(ubicacion.id) == null) {
                                    ubicacion.Agregar();
                                } else {
                                    ubicacion.Actualizar();
                                }
                            } catch (Exception ex) {
                                Global.setError(ex);
                                continue;
                            }
                        }
                    }
                }

                @Override
                public void onFailure(Call<List<Ubicacion>> call, Throwable t) {
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

        public Integer getCodigo() {
            return codigo;
        }

        public void setCodigo(Integer codigo) {
            this.codigo = codigo;
        }

        public Integer getAlmacen_id() {
            return almacen_id;
        }

        public void setAlmacen_id(Integer almacen_id) {
            this.almacen_id = almacen_id;
        }

        public String getUbicacion() {
            return ubicacion;
        }

        public void setUbicacion(String ubicacion) {
            this.ubicacion = ubicacion;
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
}