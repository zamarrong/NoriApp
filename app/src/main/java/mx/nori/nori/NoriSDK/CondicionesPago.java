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

@DatabaseTable(tableName = "condiciones_pago")
public class CondicionesPago {
    @DatabaseField(columnName = "id", id = true, unique = true)
    @SerializedName("id")
    @Expose
    private Integer id;

    @DatabaseField(columnName = "lista_precio_id")
    @SerializedName("lista_precio_id")
    @Expose
    private Integer lista_precio_id;

    @DatabaseField(columnName = "codigo")
    @SerializedName("codigo")
    @Expose
    private Short codigo;

    @DatabaseField(columnName = "nombre")
    @SerializedName("nombre")
    @Expose
    private String nombre;

    @DatabaseField(columnName = "porcentaje_descuento_total")
    @SerializedName("porcentaje_descuento_total")
    @Expose
    private String porcentaje_descuento_total;

    @DatabaseField(columnName = "porcentaje_interes")
    @SerializedName("porcentaje_interes")
    @Expose
    private String porcentaje_interes;

    @DatabaseField(columnName = "dias_extra")
    @SerializedName("dias_extra")
    @Expose
    private Short dias_extra;

    @DatabaseField(columnName = "dias_tolerancia")
    @SerializedName("dias_tolerancia")
    @Expose
    private Short dias_tolerencia;

    @DatabaseField(columnName = "limite_maximo")
    @SerializedName("limite_maximo")
    @Expose
    private Double limite_maximo;

    @DatabaseField(columnName = "limite_comprometido")
    @SerializedName("limite_comprometido")
    @Expose
    private Double limite_comprometido;

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

    public static Dao CondicionesPago()
    {
        try {
            return MainActivity.db.CondicionesPago();
        } catch (Exception ex) {
            return null;
        }
    }

    public CondicionesPago()
    {
        fecha_creacion = Functions.getCurrentDateTime();
        fecha_actualizacion = Functions.getCurrentDateTime();
    }

    public Boolean Agregar()
    {
        try {
            CondicionesPago().create(this);
            return true;
        }
        catch (Exception ex) {
            Global.setError(ex);
            return false;
        }
    }

    public static CondicionesPago Obtener(Integer id)
    {
        try
        {
            return (CondicionesPago) CondicionesPago().queryForId(id);
        } catch (Exception ex) {
            Global.setError(ex);
            return null;
        }
    }

    public static CondicionesPago Obtener(Short codigo)
    {
        try
        {
            return (CondicionesPago) CondicionesPago().queryBuilder().where().eq("codigo", codigo).queryForFirst();
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
            CondicionesPago().update(this);
            return true;
        }
        catch (Exception ex) {
            Global.setError(ex);
            return false;
        }
    }

    public static void Sincronizar()
    {
        try
        {
            List<CondicionesPago> condiciones_pago = MainActivity.api.condiciones_pago().execute().body();
            for (CondicionesPago condicion_pago : condiciones_pago) {
                try {
                    if (CondicionesPago.Obtener(condicion_pago.id) == null) {
                        condicion_pago.Agregar();
                    } else {
                        condicion_pago.Actualizar();
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
        MainActivity.api.condiciones_pago().enqueue(new Callback<List<CondicionesPago>>() {
            @Override
            public void onResponse(Call<List<CondicionesPago>> call, Response<List<CondicionesPago>> response) {
                if(response.isSuccessful()) {
                    List<CondicionesPago> condiciones_pago = response.body();
                    for (CondicionesPago condicion_pago : condiciones_pago) {
                        try {
                            if (CondicionesPago.Obtener(condicion_pago.id) == null) {
                                condicion_pago.Agregar();
                            } else {
                                condicion_pago.Actualizar();
                            }
                        } catch (Exception ex) {
                            Global.setError(ex);
                            continue;
                        }
                    }
                }
            }

            @Override
            public void onFailure(Call<List<CondicionesPago>> call, Throwable t) {
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

    public String getPorcentaje_descuento_total() {
        return porcentaje_descuento_total;
    }

    public void setPorcentaje_descuento_total(String porcentaje_descuento_total) {
        this.porcentaje_descuento_total = porcentaje_descuento_total;
    }

    public String getPorcentaje_interes() {
        return porcentaje_interes;
    }

    public void setPorcentaje_interes(String porcentaje_interes) {
        this.porcentaje_interes = porcentaje_interes;
    }

    public Short getDias_extra() {
        return dias_extra;
    }

    public void setDias_extra(Short dias_extra) {
        this.dias_extra = dias_extra;
    }

    public Short getDias_tolerencia() {
        return dias_tolerencia;
    }

    public void setDias_tolerencia(Short dias_tolerencia) {
        this.dias_tolerencia = dias_tolerencia;
    }

    public Double getLimite_maximo() {
        return limite_maximo;
    }

    public void setLimite_maximo(Double limite_maximo) {
        this.limite_maximo = limite_maximo;
    }

    public Double getLimite_comprometido() {
        return limite_comprometido;
    }

    public void setLimite_comprometido(Double limite_comprometido) {
        this.limite_comprometido = limite_comprometido;
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