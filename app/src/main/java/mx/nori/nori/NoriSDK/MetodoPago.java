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

@DatabaseTable(tableName = "metodos_pago")
public class MetodoPago {
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

    @DatabaseField(columnName = "tipo_metodo_pago_id")
    @SerializedName("tipo_metodo_pago_id")
    @Expose
    private String tipo_metodo_pago_id;

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

    public static Dao MetodosPago()
    {
        try {
            return MainActivity.db.MetodosPago();
        } catch (Exception ex) {
            return null;
        }
    }

    public MetodoPago()
    {
        usuario_creacion_id = Global.getUsuario().getId();
        fecha_creacion = Functions.getCurrentDateTime();
        usuario_actualizacion_id = Global.getUsuario().getId();
        fecha_actualizacion = Functions.getCurrentDateTime();
    }

    public Boolean Agregar()
    {
        try {
            MetodosPago().create(this);
            return true;
        }
        catch (Exception ex) {
            Global.setError(ex);
            return false;
        }
    }

    public static MetodoPago Obtener(Integer id)
    {
        try
        {
            return (MetodoPago) MetodosPago().queryForId(id);
        } catch (Exception ex) {
            Global.setError(ex);
            return null;
        }
    }

    public static MetodoPago Obtener(String codigo)
    {
        try
        {
            return (MetodoPago) MetodosPago().queryBuilder().where().eq("codigo", codigo).queryForFirst();
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
            MetodosPago().update(this);
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
        List<MetodoPago> metodos_pago = MainActivity.api.metodos_pago().execute().body();
        for (MetodoPago metodo_pago : metodos_pago) {
            try {
                if (MetodoPago.Obtener(metodo_pago.id) == null) {
                    metodo_pago.Agregar();
                } else {
                    metodo_pago.Actualizar();
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
        MainActivity.api.metodos_pago().enqueue(new Callback<List<MetodoPago>>() {
            @Override
            public void onResponse(Call<List<MetodoPago>> call, Response<List<MetodoPago>> response) {
                if(response.isSuccessful()) {
                    List<MetodoPago> metodos_pago = response.body();
                    for (MetodoPago metodo_pago : metodos_pago) {
                        try {
                            if (MetodoPago.Obtener(metodo_pago.id) == null) {
                                metodo_pago.Agregar();
                            } else {
                                metodo_pago.Actualizar();
                            }
                        } catch (Exception ex) {
                            Global.setError(ex);
                            continue;
                        }
                    }
                }
            }

            @Override
            public void onFailure(Call<List<MetodoPago>> call, Throwable t) {
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

    public String getTipo_metodo_pago_id() {
        return tipo_metodo_pago_id;
    }

    public void setTipo_metodo_pago_id(String tipo_metodo_pago_id) {
        this.tipo_metodo_pago_id = tipo_metodo_pago_id;
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

    @DatabaseTable(tableName = "tipos_metodos_pago")
    public static class Tipo {
        @DatabaseField(columnName = "id", id = true, unique = true)
        @SerializedName("id")
        @Expose
        private Integer id;

        @DatabaseField(columnName = "metodo_pago_id")
        @SerializedName("metodo_pago_id")
        @Expose
        private Integer metodo_pago_id;

        @DatabaseField(columnName = "moneda_id")
        @SerializedName("moneda_id")
        @Expose
        private Integer moneda_id;

        @DatabaseField(columnName = "nombre")
        @SerializedName("nombre")
        @Expose
        private String nombre;

        @DatabaseField(columnName = "clase")
        @SerializedName("clase")
        @Expose
        private String clase;

        @DatabaseField(columnName = "cuenta_contable")
        @SerializedName("cuenta_contable")
        @Expose
        private String cuenta_contable;

        @DatabaseField(columnName = "codigo")
        @SerializedName("codigo")
        @Expose
        private String codigo;

        @DatabaseField(columnName = "tipo_cambio")
        @SerializedName("tipo_cambio")
        @Expose
        private Character tipo_cambio;

        @DatabaseField(columnName = "referencia")
        @SerializedName("recerenica")
        @Expose
        private Boolean referencia;

        @DatabaseField(columnName = "cambio")
        @SerializedName("cambio")
        @Expose
        private Boolean cambio;

        @DatabaseField(columnName = "canjeable")
        @SerializedName("canjeable")
        @Expose
        private Boolean canjeable;

        @DatabaseField(columnName = "documento")
        @SerializedName("documento")
        @Expose
        private Boolean documento;

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

        public static Dao TiposMetodosPago()
        {
            try {
                return MainActivity.db.TiposMetodosPago();
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
                TiposMetodosPago().create(this);
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
                return (Tipo) TiposMetodosPago().queryForId(id);
            } catch (Exception ex) {
                Global.setError(ex);
                return null;
            }
        }

        public static List<Tipo> Listar()
        {
            try
            {
                return (List<Tipo>) TiposMetodosPago().queryForAll();
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
                TiposMetodosPago().update(this);
                return true;
            }
            catch (Exception ex) {
                Global.setError(ex);
                return false;
            }
        }

        public Double ObtenerTipoCambio()
        {
            try {
                switch (tipo_cambio)
                {
                    case 'C':
                        return TipoCambio.Compra(moneda_id);
                    case 'V':
                        return TipoCambio.Venta(moneda_id);
                    default:
                        return 1.00;
                }
            }
            catch (Exception ex) {
                Global.setError(ex);
                return 1.00;
            }
        }

        public static void Sincronizar()
        {
            try {
                List<Tipo> tipos = MainActivity.api.tipos_metodos_pago().execute().body();
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
            MainActivity.api.tipos_metodos_pago().enqueue(new Callback<List<Tipo>>() {
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

        public Integer getMetodo_pago_id() {
            return metodo_pago_id;
        }

        public void setMetodo_pago_id(Integer metodo_pago_id) {
            this.metodo_pago_id = metodo_pago_id;
        }

        public Integer getMoneda_id() {
            return moneda_id;
        }

        public void setMoneda_id(Integer moneda_id) {
            this.moneda_id = moneda_id;
        }

        public String getNombre() {
            return nombre;
        }

        public void setNombre(String nombre) {
            this.nombre = nombre;
        }

        public String getClase() {
            return clase;
        }

        public void setClase(String clase) {
            this.clase = clase;
        }

        public String getCuenta_contable() {
            return cuenta_contable;
        }

        public void setCuenta_contable(String cuenta_contable) {
            this.cuenta_contable = cuenta_contable;
        }

        public String getCodigo() {
            return codigo;
        }

        public void setCodigo(String codigo) {
            this.codigo = codigo;
        }

        public Character getTipo_cambio() {
            return tipo_cambio;
        }

        public void setTipo_cambio(Character tipo_cambio) {
            this.tipo_cambio = tipo_cambio;
        }

        public Boolean getReferencia() {
            return referencia;
        }

        public void setReferencia(Boolean referencia) {
            this.referencia = referencia;
        }

        public Boolean getCambio() {
            return cambio;
        }

        public void setCambio(Boolean cambio) {
            this.cambio = cambio;
        }

        public Boolean getCanjeable() {
            return canjeable;
        }

        public void setCanjeable(Boolean canjeable) {
            this.canjeable = canjeable;
        }

        public Boolean getDocumento() {
            return documento;
        }

        public void setDocumento(Boolean documento) {
            this.documento = documento;
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