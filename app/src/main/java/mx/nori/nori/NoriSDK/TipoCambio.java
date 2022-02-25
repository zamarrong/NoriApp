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

@DatabaseTable(tableName = "tipos_cambio")
public class TipoCambio {
    @DatabaseField(columnName = "id", id = true, unique = true)
    @SerializedName("id")
    @Expose
    private Integer id;

    @DatabaseField(columnName = "moneda_id")
    @SerializedName("moneda_id")
    @Expose
    private Integer moneda_id;

    @DatabaseField(columnName = "fecha")
    @SerializedName("fecha")
    @Expose
    private Date fecha;

    @DatabaseField(columnName = "compra")
    @SerializedName("compra")
    @Expose
    private Double compra;

    @DatabaseField(columnName = "venta")
    @SerializedName("venta")
    @Expose
    private Double venta;

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

    public static Dao TiposCambio()
    {
        try {
            return MainActivity.db.TiposCambio();
        } catch (Exception ex) {
            return null;
        }
    }

    public TipoCambio()
    {
        moneda_id = Global.getConfiguracion().getMoneda_id();
        compra = 1.00;
        venta = 1.00;
        fecha_creacion = Functions.getCurrentDateTime();
        fecha_actualizacion = Functions.getCurrentDateTime();
    }

    public Boolean Agregar()
    {
        try {
            TiposCambio().create(this);
            return true;
        }
        catch (Exception ex) {
            Global.setError(ex);
            return false;
        }
    }

    public static TipoCambio Obtener(Integer id)
    {
        try
        {
            return (TipoCambio) TiposCambio().queryForId(id);
        } catch (Exception ex) {
            Global.setError(ex);
            return null;
        }
    }

    public static TipoCambio ObtenerTipoCambio(Integer moneda_id)
    {
        try
        {
            return (TipoCambio) TiposCambio().queryBuilder().orderBy("id", false).where().eq("moneda_id", moneda_id).queryForFirst();
        } catch (Exception ex) {
            Global.setError(ex);
            return new TipoCambio();
        }
    }

    public static TipoCambio ObtenerTipoCambio(Date fecha, Integer moneda_id)
    {
        try
        {
            return (TipoCambio) TiposCambio().queryBuilder().orderBy("id", false).where().eq("moneda_id", moneda_id).and().eq("fecha", fecha).queryForFirst();
        } catch (Exception ex) {
            Global.setError(ex);
            return new TipoCambio();
        }
    }

    public Boolean Actualizar()
    {
        try {
            usuario_actualizacion_id = Global.getUsuario().getId();
            fecha_actualizacion = Functions.getCurrentDateTime();
            TiposCambio().update(this);
            return true;
        }
        catch (Exception ex) {
            Global.setError(ex);
            return false;
        }
    }

    public static Double Compra(Integer moneda_id)
    {
        try
        {
            return (Double) TiposCambio().queryBuilder().orderBy("id", false).selectColumns("compra").where().eq("moneda_id", moneda_id).queryForFirst();
        } catch (Exception ex) {
            Global.setError(ex);
            return 1.00;
        }
    }

    public static Double Venta(Integer moneda_id)
    {
        try
        {
            return (Double) TiposCambio().queryBuilder().orderBy("id", false).selectColumns("venta").where().eq("moneda_id", moneda_id).queryForFirst();
        } catch (Exception ex) {
            Global.setError(ex);
            return 1.00;
        }
    }

    public static Double Convertir(Integer moneda_origen_id, Integer moneda_destino_id, Character tipo, Double cantidad)
    {
        try
        {
            TipoCambio origen = ObtenerTipoCambio(moneda_origen_id);
            TipoCambio destino = ObtenerTipoCambio(moneda_destino_id);

            switch (tipo)
            {
                case 'V':
                    return (origen.venta * cantidad) / destino.venta;
                case 'C':
                    return (origen.compra * cantidad) / destino.compra;
                default:
                    return 1.00;
            }

        } catch (Exception ex) {
            Global.setError(ex);
            return 1.00;
        }
    }

    public static void Sincronizar(String fecha)
    {
        try {
            List<TipoCambio> tipos_cambio = MainActivity.api.tipos_cambio(fecha).execute().body();
            for (TipoCambio tipo_cambio : tipos_cambio) {
                try {
                    if (TipoCambio.Obtener(tipo_cambio.id) == null) {
                        tipo_cambio.Agregar();
                    } else {
                        tipo_cambio.Actualizar();
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

    public static void SincronizarAsync(String fecha)
    {
        MainActivity.api.tipos_cambio(fecha).enqueue(new Callback<List<TipoCambio>>() {
            @Override
            public void onResponse(Call<List<TipoCambio>> call, Response<List<TipoCambio>> response) {
                if(response.isSuccessful()) {
                    List<TipoCambio> tipos_cambio = response.body();
                    for (TipoCambio tipo_cambio : tipos_cambio) {
                        try {
                            if (TipoCambio.Obtener(tipo_cambio.id) == null) {
                                tipo_cambio.Agregar();
                            } else {
                                tipo_cambio.Actualizar();
                            }
                        } catch (Exception ex) {
                            Global.setError(ex);
                            continue;
                        }
                    }
                }
            }

            @Override
            public void onFailure(Call<List<TipoCambio>> call, Throwable t) {
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

    public Integer getMoneda_id() {
        return moneda_id;
    }

    public void setMoneda_id(Integer moneda_id) {
        this.moneda_id = moneda_id;
    }

    public Date getFecha() {
        return fecha;
    }

    public void setFecha(Date fecha) {
        this.fecha = fecha;
    }

    public Double getCompra() {
        return compra;
    }

    public void setCompra(Double compra) {
        this.compra = compra;
    }

    public Double getVenta() {
        return venta;
    }

    public void setVenta(Double venta) {
        this.venta = venta;
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