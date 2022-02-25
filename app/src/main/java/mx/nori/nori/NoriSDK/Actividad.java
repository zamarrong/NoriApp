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

@DatabaseTable(tableName = "actividades")
public class Actividad {
    @DatabaseField(columnName = "id", generatedId = true, unique = true)
    @SerializedName("id")
    @Expose
    private Integer id;

    @DatabaseField(columnName = "socio_id")
    @SerializedName("socio_id")
    @Expose
    private Integer socio_id;

    @DatabaseField(columnName = "persona_contacto_id")
    @SerializedName("persona_contacto_id")
    @Expose
    private Integer persona_contacto_id;

    @DatabaseField(columnName = "vendedor_id")
    @SerializedName("vendedor_id")
    @Expose
    private Integer vendedor_id;

    @DatabaseField(columnName = "tipo_actividad_id")
    @SerializedName("tipo_actividad_id")
    @Expose
    private Integer tipo_actividad_id;

    @DatabaseField(columnName = "causalidad_id")
    @SerializedName("causalidad_id")
    @Expose
    private Integer causalidad_id;

    @DatabaseField(columnName = "comentarios")
    @SerializedName("comentarios")
    @Expose
    private String comentarios;

    @DatabaseField(columnName = "notas")
    @SerializedName("notas")
    @Expose
    private String notas;

    @DatabaseField(columnName = "latitud")
    @SerializedName("latitud")
    @Expose
    private Double latitud;

    @DatabaseField(columnName = "longitud")
    @SerializedName("longitud")
    @Expose
    private Double longitud;

    @DatabaseField(columnName = "identificador_externo")
    @SerializedName("identificador_externo")
    @Expose
    private Integer identificador_externo;

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

    public static Dao Actividades()
    {
        try {
            return MainActivity.db.Actividades();
        } catch (Exception ex) {
            return null;
        }
    }

    public Actividad()
    {
        id = socio_id = persona_contacto_id = tipo_actividad_id = causalidad_id = identificador_externo = 0;
        vendedor_id = Global.getUsuario().getVendedor_id();
        usuario_creacion_id = Global.getUsuario().getId();
        fecha_creacion = Functions.getCurrentDateTime();
        usuario_actualizacion_id = Global.getUsuario().getId();
        fecha_actualizacion = Functions.getCurrentDateTime();
    }

    public Boolean Agregar()
    {
        try {
            Actividades().create(this);
            return true;
        }
        catch (Exception ex) {
            Global.setError(ex);
            return false;
        }
    }

    public static Actividad Obtener(Integer id)
    {
        try
        {
            return (Actividad) Actividades().queryForId(id);
        } catch (Exception ex) {
            Global.setError(ex);
            return null;
        }
    }

    public static List<Actividad> Listar() {
        try {
            return (List<Actividad>) Actividades().queryForAll();
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
            Actividades().update(this);
            return true;
        }
        catch (Exception ex) {
            Global.setError(ex);
            return false;
        }
    }

    public static void Sincronizar() {
        try {
            List<Actividad> actividades = Actividades().queryForEq("identificador_externo", 0);

            for(Actividad actividad : actividades) {
                try {
                    Actividad actividad_agregada = MainActivity.api.actividad(actividad).execute().body();
                    actividad.identificador_externo = actividad_agregada.getId();
                    actividad.Actualizar();
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

    public Integer getId() {
        return id;
    }

    public void setId(Integer id) {
        this.id = id;
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

    public Integer getVendedor_id() {
        return vendedor_id;
    }

    public void setVendedor_id(Integer vendedor_id) {
        this.vendedor_id = vendedor_id;
    }

    public Integer getTipo_actividad_id() {
        return tipo_actividad_id;
    }

    public void setTipo_actividad_id(Integer tipo_actividad_id) {
        this.tipo_actividad_id = tipo_actividad_id;
    }

    public Integer getCausalidad_id() {
        return causalidad_id;
    }

    public void setCausalidad_id(Integer causalidad_id) {
        this.causalidad_id = causalidad_id;
    }

    public String getComentarios() {
        return comentarios;
    }

    public void setComentarios(String comentarios) {
        this.comentarios = comentarios;
    }

    public String getNotas() {
        return notas;
    }

    public void setNotas(String notas) {
        this.notas = notas;
    }

    public Double getLatitud() {
        return latitud;
    }

    public void setLatitud(Double latitud) {
        this.latitud = latitud;
    }

    public Double getLongitud() {
        return longitud;
    }

    public void setLongitud(Double longitud) {
        this.longitud = longitud;
    }

    public Integer getIdentificador_externo() {
        return identificador_externo;
    }

    public void setIdentificador_externo(Integer identificador_externo) {
        this.identificador_externo = identificador_externo;
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

    @DatabaseTable(tableName = "tipos_actividades")
    public static class Tipo {
        @DatabaseField(columnName = "id", id = true, unique = true)
        @SerializedName("id")
        @Expose
        private Integer id;

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

        public static Dao TiposActividades()
        {
            try {
                return MainActivity.db.TiposActividades();
            } catch (Exception ex) {
                return null;
            }
        }

        public Tipo()
        {
            fecha_creacion = Functions.getCurrentDateTime();
            fecha_actualizacion = Functions.getCurrentDateTime();
        }

        public Boolean Agregar()
        {
            try {
                TiposActividades().create(this);
                return true;
            }
            catch (Exception ex) {
                Global.setError(ex);
                return false;
            }
        }

        public static Tipo Obtener(Integer id)
        {
            try
            {
                return (Tipo) TiposActividades().queryForId(id);
            } catch (Exception ex) {
                Global.setError(ex);
                return null;
            }
        }

        public static List<Tipo> Listar()
        {
            try
            {
                return (List<Tipo>) TiposActividades().queryForAll();
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
                TiposActividades().update(this);
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
                List<Tipo> tipos = MainActivity.api.tipos_actividades().execute().body();
                for (Tipo tipo : tipos) {
                    try {
                        if (Tipo.Obtener(tipo.id) == null) {
                            tipo.Agregar();
                        } else {
                            tipo.Actualizar();
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
            MainActivity.api.tipos_actividades().enqueue(new Callback<List<Tipo>>() {
                @Override
                public void onResponse(Call<List<Tipo>> call, Response<List<Tipo>> response) {
                    if(response.isSuccessful()) {
                        List<Tipo> tipos = response.body();
                        for (Tipo tipo : tipos) {
                            try {
                                if (Tipo.Obtener(tipo.id) == null) {
                                    tipo.Agregar();
                                } else {
                                    tipo.Actualizar();
                                }
                            } catch (Exception ex) {
                                Global.setError(ex);
                                continue;
                            }
                        }
                    }
                }

                @Override
                public void onFailure(Call<List<Tipo>> call, Throwable t) {
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
}