package mx.nori.nori.NoriSDK;

import com.google.gson.annotations.Expose;
import com.google.gson.annotations.SerializedName;
import com.j256.ormlite.dao.Dao;
import com.j256.ormlite.field.DatabaseField;
import com.j256.ormlite.table.DatabaseTable;

import java.time.LocalDate;
import java.util.Calendar;
import java.util.Date;

import mx.nori.nori.Functions;
import mx.nori.nori.MainActivity;

@DatabaseTable(tableName = "fechas_sincronizacion")
public class FechaSincronizacion {
    @DatabaseField(columnName = "id", generatedId = true, unique = true)
    @SerializedName("id")
    @Expose
    private Integer id;

    @DatabaseField(columnName = "tabla")
    @SerializedName("tabla")
    @Expose
    private String tabla;

    @DatabaseField(columnName = "fecha")
    @SerializedName("fecha")
    @Expose
    private Date fecha;

    public static Dao FechasSincronizacion()
    {
        try {
            return MainActivity.db.FechasSincronizacion();
        } catch (Exception ex) {
            return null;
        }
    }

    public FechaSincronizacion() {
        fecha = Functions.getMinDateTime();
    }

    public Boolean Agregar()
    {
        try {
            FechasSincronizacion().create(this);
            return true;
        }
        catch (Exception ex) {
            Global.setError(ex);
            return false;
        }
    }

    public static FechaSincronizacion Obtener(Integer id)
    {
        try
        {
            return (FechaSincronizacion) FechasSincronizacion().queryForId(id);
        } catch (Exception ex) {
            Global.setError(ex);
            return null;
        }
    }

    public static FechaSincronizacion Obtener(String tabla)
    {
        try
        {
            return (FechaSincronizacion) FechasSincronizacion().queryBuilder().where().eq("tabla", tabla).queryForFirst();
        } catch (Exception ex) {
            Global.setError(ex);
            return null;
        }
    }

    public Boolean Actualizar()
    {
        try {
            fecha = Functions.getCurrentDateTime();
            FechasSincronizacion().update(this);
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

    public String getTabla() {
        return tabla;
    }

    public void setTabla(String tabla) {
        this.tabla = tabla;
    }

    public Date getFecha() {
        return fecha;
    }

    public void setFecha(Date fecha) {
        this.fecha = fecha;
    }
}
