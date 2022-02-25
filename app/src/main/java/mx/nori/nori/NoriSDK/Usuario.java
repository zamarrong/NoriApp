package mx.nori.nori.NoriSDK;

import android.telephony.TelephonyManager;

import com.google.gson.annotations.Expose;
import com.google.gson.annotations.SerializedName;
import com.j256.ormlite.dao.Dao;
import com.j256.ormlite.field.DatabaseField;
import com.j256.ormlite.table.DatabaseTable;

import java.util.ArrayList;
import java.util.Date;
import java.util.List;

import mx.nori.nori.Functions;
import mx.nori.nori.MainActivity;
import retrofit2.Call;
import retrofit2.Callback;
import retrofit2.Response;

@DatabaseTable(tableName = "usuarios")
public class Usuario {
    @DatabaseField(columnName = "id", id = true, unique = true)
    @SerializedName("id")
    @Expose
    private Integer id;

    @DatabaseField(columnName = "almacen_id")
    @SerializedName("almacen_id")
    @Expose
    private Integer almacen_id;

    @DatabaseField(columnName = "ubicacion_id")
    @SerializedName("ubicacion_id")
    @Expose
    private Integer ubicacion_id;

    @DatabaseField(columnName = "departamento_id")
    @SerializedName("departamento_id")
    @Expose
    private Integer departamento_id;

    @DatabaseField(columnName = "vendedor_id")
    @SerializedName("vendedor_id")
    @Expose
    private Integer vendedor_id;

    @DatabaseField(columnName = "socio_id")
    @SerializedName("socio_id")
    @Expose
    private Integer socio_id;

    @DatabaseField(columnName = "estado_id")
    @SerializedName("estado_id")
    @Expose
    private Integer estado_id;

    @DatabaseField(columnName = "clase_expedicion_id")
    @SerializedName("clase_expedicion_id")
    @Expose
    private Integer clase_expedicion_id;

    @DatabaseField(columnName = "rol")
    @SerializedName("rol")
    @Expose
    private Character rol;

    @DatabaseField(columnName = "usuario")
    @SerializedName("usuario")
    @Expose
    private String usuario;

    @DatabaseField(columnName = "nombre")
    @SerializedName("nombre")
    @Expose
    private String nombre;

    @DatabaseField(columnName = "correo")
    @SerializedName("correo")
    @Expose
    private String correo;

    @DatabaseField(columnName = "contraseña")
    @SerializedName("contraseña")
    @Expose
    private String contraseña;

    @DatabaseField(columnName = "norma_reparto")
    @SerializedName("norma_reparto")
    @Expose
    private String norma_reparto;

    @DatabaseField(columnName = "dispositivo")
    @SerializedName("dispositivo")
    @Expose
    private String dispositivo;

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

    public static Dao Usuarios()
    {
        try {
            return MainActivity.db.Usuarios();
        } catch (Exception ex) {
            return null;
        }
    }

    public Usuario()
    {
        id = 0;
        ubicacion_id = 0;
        fecha_creacion = Functions.getCurrentDateTime();
        fecha_actualizacion = Functions.getCurrentDateTime();
    }

    public Boolean Agregar()
    {
        try {
            Usuarios().create(this);
            return true;
        }
        catch (Exception ex) {
            Global.setError(ex);
            return false;
        }
    }

    public static Usuario Obtener()
    {
        try
        {
            return (Usuario) Usuarios().queryBuilder().where().eq("dispositivo", Global.getIMEI()).queryForFirst();
        } catch (Exception ex) {
            Global.setError(ex);
            return null;
        }
    }

    public static Usuario Obtener(Integer id)
    {
        try
        {
            return (Usuario) Usuarios().queryForId(id);
        } catch (Exception ex) {
            Global.setError(ex);
            return null;
        }
    }

    public static Usuario Obtener(String usuario)
    {
        try
        {
            return (Usuario) Usuarios().queryBuilder().where().eq("usuario", usuario).queryForFirst();
        } catch (Exception ex) {
            Global.setError(ex);
            Sincronizar();
            return null;
        }
    }

    public Ruta ObtenerRuta()
    {
        try
        {
            Vendedor vendedor = Vendedor.Obtener(vendedor_id);
            Ruta ruta = Ruta.Obtener(vendedor.getRuta_id());
            return ruta;
        } catch (Exception ex) {
            Global.setError(ex);
            return null;
        }
    }

    public Boolean Actualizar()
    {
        try {
            Usuarios().update(this);
            return true;
        }
        catch (Exception ex) {
            Global.setError(ex);
            return false;
        }
    }

    public List<mx.nori.nori.NoriSDK.ListaPrecio> ListasPrecios()
    {
        try
        {
            List<ListaPrecio> usuarios_listas_precios = ListaPrecio.ObtenerPorUsuario(id);
            List<mx.nori.nori.NoriSDK.ListaPrecio> listas_precios = new ArrayList<>();
            for (ListaPrecio usuario_lista_precio : usuarios_listas_precios) {
                mx.nori.nori.NoriSDK.ListaPrecio lista_precio = mx.nori.nori.NoriSDK.ListaPrecio.Obtener(usuario_lista_precio.getLista_precio_id());
                if (lista_precio != null) {
                    listas_precios.add(lista_precio);
                }
            }

            return listas_precios;
        } catch (Exception ex) {
            Global.setError(ex);
            return null;
        }
    }

    public static void Sincronizar()
    {
        try {
            List<Usuario> usuarios = MainActivity.api.usuarios().execute().body();
            for (Usuario usuario : usuarios) {
                try {
                    if (Usuario.Obtener(usuario.id) == null) {
                        usuario.Agregar();
                    } else {
                        usuario.Actualizar();
                    }

                    ListaPrecio.Sincronizar(usuario.id);
                } catch (Exception ex) {
                    Global.setError(ex);
                    continue;
                }
            }
        } catch (Exception ex) {
            Global.setError(ex);
        } finally {
            Global.Inicilizar();
        }
    }

    public static void SincronizarAsync()
    {
        MainActivity.api.usuarios().enqueue(new Callback<List<Usuario>>() {
            @Override
            public void onResponse(Call<List<Usuario>> call, Response<List<Usuario>> response) {
                if(response.isSuccessful()) {
                    List<Usuario> usuarios = response.body();
                    for (Usuario usuario : usuarios) {
                        try {
                            if (Usuario.Obtener(usuario.id) == null) {
                                usuario.Agregar();
                            } else {
                                usuario.Actualizar();
                            }
                        } catch (Exception ex) {
                            Global.setError(ex);
                            continue;
                        }
                    }
                }
            }

            @Override
            public void onFailure(Call<List<Usuario>> call, Throwable t) {
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

    public Integer getAlmacen_id() {
        return almacen_id;
    }

    public void setAlmacen_id(Integer almacen_id) {
        this.almacen_id = almacen_id;
    }

    public Integer getUbicacion_id() {
        return ubicacion_id;
    }

    public void setUbicacion_id(Integer ubicacion_id) {
        this.ubicacion_id = ubicacion_id;
    }

    public Integer getDepartamento_id() {
        return departamento_id;
    }

    public void setDepartamento_id(Integer departamento_id) {
        this.departamento_id = departamento_id;
    }

    public Integer getVendedor_id() {
        return vendedor_id;
    }

    public void setVendedor_id(Integer vendedor_id) {
        this.vendedor_id = vendedor_id;
    }

    public Integer getSocio_id() {
        return socio_id;
    }

    public void setSocio_id(Integer socio_id) {
        this.socio_id = socio_id;
    }

    public Integer getEstado_id() {
        return estado_id;
    }

    public void setEstado_id(Integer estado_id) {
        this.estado_id = estado_id;
    }

    public Integer getClase_expedicion_id() {
        return clase_expedicion_id;
    }

    public void setClase_expedicion_id(Integer clase_expedicion_id) {
        this.clase_expedicion_id = clase_expedicion_id;
    }

    public Character getRol() {
        return rol;
    }

    public void setRol(Character rol) {
        this.rol = rol;
    }

    public String getUsuario() {
        return usuario;
    }

    public void setUsuario(String usuario) {
        this.usuario = usuario;
    }

    public String getNombre() {
        return nombre;
    }

    public void setNombre(String nombre) {
        this.nombre = nombre;
    }

    public String getCorreo() {
        return correo;
    }

    public void setCorreo(String correo) {
        this.correo = correo;
    }

    public String getContraseña() {
        return contraseña;
    }

    public void setContraseña(String contraseña) {
        this.contraseña = contraseña;
    }

    public String getNorma_reparto() {
        return norma_reparto;
    }

    public void setNorma_reparto(String norma_reparto) {
        this.norma_reparto = norma_reparto;
    }

    public String getDispositivo() {
        return dispositivo;
    }

    public void setDispositivo(String dispositivo) {
        this.dispositivo = dispositivo;
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

    @DatabaseTable(tableName = "usuarios_listas_precios")
    public static class ListaPrecio {
        @DatabaseField(columnName = "id", id = true, unique = true)
        @SerializedName("id")
        @Expose
        private Integer id;

        @DatabaseField(columnName = "lista_precio_id")
        @SerializedName("lista_precio_id")
        @Expose
        private Integer lista_precio_id;

        @DatabaseField(columnName = "usuario_id")
        @SerializedName("usuario_id")
        @Expose
        private Integer usuario_id;

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

        public static Dao ListasPrecios() {
            try {
                return MainActivity.db.UsuariosListasPrecios();
            } catch (Exception ex) {
                return null;
            }
        }

        public ListaPrecio() {
            fecha_creacion = Functions.getCurrentDateTime();
            fecha_actualizacion = Functions.getCurrentDateTime();
        }

        public Boolean Agregar() {
            try {
                ListasPrecios().create(this);
                return true;
            } catch (Exception ex) {
                Global.setError(ex);
                return false;
            }
        }

        public static ListaPrecio Obtener(Integer id) {
            try {
                return (ListaPrecio) ListasPrecios().queryForId(id);
            } catch (Exception ex) {
                Global.setError(ex);
                return null;
            }
        }

        public static List<ListaPrecio> ObtenerPorUsuario(int usuario_id) {
            try {
                return (List<ListaPrecio>) ListasPrecios().queryForEq("usuario_id", usuario_id);
            } catch (Exception ex) {
                Global.setError(ex);
                return null;
            }
        }

        public static List<ListaPrecio> Listar() {
            try {
                return (List<ListaPrecio>) ListasPrecios().queryForAll();
            } catch (Exception ex) {
                Global.setError(ex);
                return null;
            }
        }

        public Boolean Actualizar() {
            try {
                usuario_actualizacion_id = Global.getUsuario().getId();
                fecha_actualizacion = Functions.getCurrentDateTime();
                ListasPrecios().update(this);
                return true;
            } catch (Exception ex) {
                Global.setError(ex);
                return false;
            }
        }

        public static void EliminarListas(int usuario_id) {
            try {
                List<ListaPrecio> listas_precios = ListasPrecios().queryForEq("usuario_id", usuario_id);
                for (ListaPrecio lista_precio : listas_precios) {
                   ListasPrecios().delete(lista_precio);
                }
            } catch (Exception ex) {
                Global.setError(ex);
            }
        }

        public static void Sincronizar(int id) {
            try {
                List<ListaPrecio> listas_precios = MainActivity.api.usuarios_listas_precios(id).execute().body();
                EliminarListas(id);
                for (ListaPrecio lista_precio : listas_precios) {
                    try {
                        if (ListaPrecio.Obtener(lista_precio.id) == null) {
                            lista_precio.Agregar();
                        } else {
                            lista_precio.Actualizar();
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

        public static void SincronizarAsync(int id) {
            MainActivity.api.usuarios_listas_precios(id).enqueue(new Callback<List<ListaPrecio>>() {
                @Override
                public void onResponse(Call<List<ListaPrecio>> call, Response<List<ListaPrecio>> response) {
                    if (response.isSuccessful()) {
                        List<ListaPrecio> listas_precios = response.body();
                        for (ListaPrecio lista_precio : listas_precios) {
                            try {
                                if (ListaPrecio.Obtener(lista_precio.id) == null) {
                                    lista_precio.Agregar();
                                } else {
                                    lista_precio.Actualizar();
                                }
                            } catch (Exception ex) {
                                Global.setError(ex);
                                continue;
                            }
                        }
                    }
                }

                @Override
                public void onFailure(Call<List<ListaPrecio>> call, Throwable t) {
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

        public Integer getLista_precio_id() {
            return lista_precio_id;
        }

        public void setLista_precio_id(Integer lista_precio_id) {
            this.lista_precio_id = lista_precio_id;
        }

        public Integer getUsuario_id() {
            return usuario_id;
        }

        public void setUsuario_id(Integer usuario_id) {
            this.usuario_id = usuario_id;
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