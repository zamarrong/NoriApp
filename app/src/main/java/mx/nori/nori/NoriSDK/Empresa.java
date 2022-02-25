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

@DatabaseTable(tableName = "empresa")
public class Empresa {
    @DatabaseField(columnName = "id", id = true, unique = true)
    @SerializedName("id")
    @Expose
    private Integer id;

    @DatabaseField(columnName = "nombre_fiscal")
    @SerializedName("nombre_fiscal")
    @Expose
    private String nombre_fiscal;

    @DatabaseField(columnName = "nombre_comercial")
    @SerializedName("nombre_comercial")
    @Expose
    private String nombre_comercial;

    @DatabaseField(columnName = "eslogan")
    @SerializedName("eslogan")
    @Expose
    private String eslogan;

    @DatabaseField(columnName = "logotipo")
    @SerializedName("logotipo")
    @Expose
    private String logotipo;

    @DatabaseField(columnName = "rfc")
    @SerializedName("rfc")
    @Expose
    private String rfc;

    @DatabaseField(columnName = "regimen_fiscal")
    @SerializedName("regimen_fiscal")
    @Expose
    private String regimen_fiscal;

    @DatabaseField(columnName = "tipo_persona")
    @SerializedName("tipo_persona")
    @Expose
    private Character tipo_persona;

    @DatabaseField(columnName = "telefono")
    @SerializedName("telefono")
    @Expose
    private String telefono;

    @DatabaseField(columnName = "telefono2")
    @SerializedName("telefono2")
    @Expose
    private String telefono2;

    @DatabaseField(columnName = "correo")
    @SerializedName("correo")
    @Expose
    private String correo;

    @DatabaseField(columnName = "sitio_web")
    @SerializedName("sitio_web")
    @Expose
    private String sitio_web;

    @DatabaseField(columnName = "calle")
    @SerializedName("calle")
    @Expose
    private String calle;

    @DatabaseField(columnName = "numero_exterior")
    @SerializedName("numero_exterior")
    @Expose
    private String numero_exterior;

    @DatabaseField(columnName = "numero_interior")
    @SerializedName("numero_interior")
    @Expose
    private String numero_interior;

    @DatabaseField(columnName = "cp")
    @SerializedName("cp")
    @Expose
    private String cp;

    @DatabaseField(columnName = "colonia")
    @SerializedName("colonia")
    @Expose
    private String colonia;

    @DatabaseField(columnName = "ciudad")
    @SerializedName("ciudad")
    @Expose
    private String ciudad;

    @DatabaseField(columnName = "municipio")
    @SerializedName("municipio")
    @Expose
    private String municipio;

    @DatabaseField(columnName = "estado")
    @SerializedName("estado")
    @Expose
    private String estado;

    @DatabaseField(columnName = "pais")
    @SerializedName("pais")
    @Expose
    private String pais;

    @DatabaseField(columnName = "fecha_creacion")
    private transient Date fecha_creacion;

    @DatabaseField(columnName = "usuario_actualizacion_id")
    @SerializedName("usuario_actualizacion_id")
    @Expose
    private Integer usuario_actualizacion_id;

    @DatabaseField(columnName = "fecha_actualizacion")
    private transient Date fecha_actualizacion;

    public static Dao Empresa()
    {
        try {
            return MainActivity.db.Empresa();
        } catch (Exception ex) {
            return null;
        }
    }

    public Empresa()
    {
        fecha_creacion = Functions.getCurrentDateTime();
        fecha_actualizacion = Functions.getCurrentDateTime();
    }

    public Boolean Agregar()
    {
        try {
            Empresa().create(this);
            return true;
        }
        catch (Exception ex) {
            Global.setError(ex);
            return false;
        }
    }

    public static Empresa Obtener()
    {
        try
        {
            return (Empresa) Empresa().queryForId(1);
        } catch (Exception ex) {
            Global.setError(ex);
            return null;
        }
    }

    public Boolean Actualizar()
    {
        try {
            Empresa().update(this);
            return true;
        }
        catch (Exception ex) {
            Global.setError(ex);
            return false;
        }
    }

    public String Bloque()
    {
        try
        {
            return String.format("{0} {1} {2} {3} {4} {5} {6} {7} {8}", calle, numero_exterior, numero_interior, colonia, ciudad, cp, municipio, estado, pais);
        }
        catch (Exception ex)
        {
            Global.setError(ex);
            return "";
        }
    }

    public static void Sincronizar()
    {
        try {
            Empresa empresa = MainActivity.api.empresa().execute().body();
            try {
                if (Empresa.Obtener() == null) {
                    empresa.Agregar();
                } else {
                    empresa.Actualizar();
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
        MainActivity.api.empresa().enqueue(new Callback<Empresa>() {
            @Override
            public void onResponse(Call<Empresa> call, Response<Empresa> response) {
                if(response.isSuccessful()) {
                    Empresa empresa = response.body();
                    try {
                        if (Empresa.Obtener() == null) {
                            empresa.Agregar();
                        } else {
                            empresa.Actualizar();
                        }
                    } catch (Exception ex) {
                        Global.setError(ex);
                    }
                }
            }

            @Override
            public void onFailure(Call<Empresa> call, Throwable t) {
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

    public String getNombre_fiscal() {
        return nombre_fiscal;
    }

    public void setNombre_fiscal(String nombre_fiscal) {
        this.nombre_fiscal = nombre_fiscal;
    }

    public String getNombre_comercial() {
        return nombre_comercial;
    }

    public void setNombre_comercial(String nombre_comercial) {
        this.nombre_comercial = nombre_comercial;
    }

    public String getEslogan() {
        return eslogan;
    }

    public void setEslogan(String eslogan) {
        this.eslogan = eslogan;
    }

    public String getLogotipo() {
        return logotipo;
    }

    public void setLogotipo(String logotipo) {
        this.logotipo = logotipo;
    }

    public String getRfc() {
        return rfc;
    }

    public void setRfc(String rfc) {
        this.rfc = rfc;
    }

    public String getRegimen_fiscal() {
        return regimen_fiscal;
    }

    public void setRegimen_fiscal(String regimen_fiscal) {
        this.regimen_fiscal = regimen_fiscal;
    }

    public Character getTipo_persona() {
        return tipo_persona;
    }

    public void setTipo_persona(Character tipo_persona) {
        this.tipo_persona = tipo_persona;
    }

    public String getTelefono() {
        return telefono;
    }

    public void setTelefono(String telefono) {
        this.telefono = telefono;
    }

    public String getTelefono2() {
        return telefono2;
    }

    public void setTelefono2(String telefono2) {
        this.telefono2 = telefono2;
    }

    public String getCorreo() {
        return correo;
    }

    public void setCorreo(String correo) {
        this.correo = correo;
    }

    public String getSitio_web() {
        return sitio_web;
    }

    public void setSitio_web(String sitio_web) {
        this.sitio_web = sitio_web;
    }

    public String getCalle() {
        return calle;
    }

    public void setCalle(String calle) {
        this.calle = calle;
    }

    public String getNumero_exterior() {
        return numero_exterior;
    }

    public void setNumero_exterior(String numero_exterior) {
        this.numero_exterior = numero_exterior;
    }

    public String getNumero_interior() {
        return numero_interior;
    }

    public void setNumero_interior(String numero_interior) {
        this.numero_interior = numero_interior;
    }

    public String getCp() {
        return cp;
    }

    public void setCp(String cp) {
        this.cp = cp;
    }

    public String getColonia() {
        return colonia;
    }

    public void setColonia(String colonia) {
        this.colonia = colonia;
    }

    public String getCiudad() {
        return ciudad;
    }

    public void setCiudad(String ciudad) {
        this.ciudad = ciudad;
    }

    public String getMunicipio() {
        return municipio;
    }

    public void setMunicipio(String municipio) {
        this.municipio = municipio;
    }

    public String getEstado() {
        return estado;
    }

    public void setEstado(String estado) {
        this.estado = estado;
    }

    public String getPais() {
        return pais;
    }

    public void setPais(String pais) {
        this.pais = pais;
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