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

@DatabaseTable(tableName = "flujo")
public class Flujo {
    @DatabaseField(columnName = "id", generatedId = true, unique = true)
    @SerializedName("id")
    @Expose
    private Integer id;

    @DatabaseField(columnName = "documento_id")
    @SerializedName("documento_id")
    @Expose
    private Integer documento_id;

    @DatabaseField(columnName = "pago_id")
    @SerializedName("pago_id")
    @Expose
    private Integer pago_id;

    @DatabaseField(columnName = "codigo")
    @SerializedName("codigo")
    @Expose
    private String codigo;

    @DatabaseField(columnName = "tipo_metodo_pago_id")
    @SerializedName("tipo_metodo_pago_id")
    @Expose
    private Integer tipo_metodo_pago_id;

    @DatabaseField(columnName = "tipo_cambio")
    @SerializedName("tipo_cambio")
    @Expose
    private Double tipo_cambio;

    @DatabaseField(columnName = "importe")
    @SerializedName("importe")
    @Expose
    private Double importe;

    @DatabaseField(columnName = "referencia")
    @SerializedName("referecnia")
    @Expose
    private String referencia;

    @DatabaseField(columnName = "comentario")
    @SerializedName("comentario")
    @Expose
    private String comentario;

    @DatabaseField(columnName = "autorizacion_id")
    @SerializedName("autorizacion_id")
    @Expose
    private Integer autorizacion_id;

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

    public static Dao Flujo()
    {
        try {
            return MainActivity.db.Flujo();
        } catch (Exception ex) {
            return null;
        }
    }

    public Flujo()
    {
        id = 0;
        documento_id = 0;
        pago_id = 0;
        codigo = "INVEN";
        tipo_metodo_pago_id = 0;
        tipo_cambio = 1.0;
        importe = 0.0;
        referencia = "";
        comentario = "";
        autorizacion_id = 0;
        usuario_creacion_id = Global.getUsuario().getId();
        fecha_creacion = Functions.getCurrentDateTime();
        usuario_actualizacion_id = Global.getUsuario().getId();
        fecha_actualizacion = Functions.getCurrentDateTime();
    }

    public Boolean Agregar()
    {
        try {
            if (documento_id == 0 || importe == 0 || tipo_metodo_pago_id == 0)
            {
                return  false;
            }

            Flujo().create(this);
            return true;
        }
        catch (Exception ex) {
            Global.setError(ex);
            return false;
        }
    }

    public static Flujo Obtener(Integer id)
    {
        try
        {
            return (Flujo) Flujo().queryForId(id);
        } catch (Exception ex) {
            Global.setError(ex);
            return null;
        }
    }

    public static List<Flujo> Listar()
    {
        try {
            return (List<Flujo>) Flujo().queryForAll();
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
            Flujo().update(this);
            return true;
        }
        catch (Exception ex) {
            Global.setError(ex);
            return false;
        }
    }

    public Integer getId() {
        return id;
    }

    public void setId(Integer id) {
        this.id = id;
    }

    public Integer getDocumento_id() {
        return documento_id;
    }

    public void setDocumento_id(Integer documento_id) {
        this.documento_id = documento_id;
    }

    public Integer getPago_id() {
        return pago_id;
    }

    public void setPago_id(Integer pago_id) {
        this.pago_id = pago_id;
    }

    public String getCodigo() {
        return codigo;
    }

    public void setCodigo(String codigo) {
        this.codigo = codigo;
    }

    public Integer getTipo_metodo_pago_id() {
        return tipo_metodo_pago_id;
    }

    public void setTipo_metodo_pago_id(Integer tipo_metodo_pago_id) {
        this.tipo_metodo_pago_id = tipo_metodo_pago_id;
    }

    public Double getTipo_cambio() {
        return tipo_cambio;
    }

    public void setTipo_cambio(Double tipo_cambio) {
        this.tipo_cambio = tipo_cambio;
    }

    public Double getImporte() {
        return importe;
    }

    public void setImporte(Double importe) {
        this.importe = importe;
    }

    public String getReferencia() {
        return referencia;
    }

    public void setReferencia(String referencia) {
        this.referencia = referencia;
    }

    public String getComentario() {
        return comentario;
    }

    public void setComentario(String comentario) {
        this.comentario = comentario;
    }

    public Integer getAutorizacion_id() {
        return autorizacion_id;
    }

    public void setAutorizacion_id(Integer autorizacion_id) {
        this.autorizacion_id = autorizacion_id;
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