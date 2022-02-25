package mx.nori.nori.NoriSDK;

import android.os.AsyncTask;

import com.google.gson.annotations.Expose;
import com.google.gson.annotations.SerializedName;
import com.j256.ormlite.dao.Dao;
import com.j256.ormlite.field.DatabaseField;
import com.j256.ormlite.table.DatabaseTable;

import java.util.Date;
import java.util.List;

import mx.nori.nori.Functions;
import mx.nori.nori.MainActivity;
import mx.nori.nori.Nori;
import retrofit2.Call;
import retrofit2.Callback;
import retrofit2.Response;

@DatabaseTable(tableName = "socios")
public class Socio {
    @DatabaseField(columnName = "id", id = true, unique = true)
    @SerializedName("id")
    @Expose
    private Integer id;

    @DatabaseField(columnName = "lista_precio_id")
    @SerializedName("lista_precio_id")
    @Expose
    private Integer lista_precio_id;

    @DatabaseField(columnName = "moneda_id")
    @SerializedName("moneda_id")
    @Expose
    private Integer moneda_id;

    @DatabaseField(columnName = "condicion_pago_id")
    @SerializedName("condicion_pago_id")
    @Expose
    private Integer condicion_pago_id;

    @DatabaseField(columnName = "grupo_socio_id")
    @SerializedName("grupo_socio_id")
    @Expose
    private Integer grupo_socio_id;

    @DatabaseField(columnName = "metodo_pago_id")
    @SerializedName("metodo_pago_id")
    @Expose
    private Integer metodo_pago_id;

    @DatabaseField(columnName = "vendedor_id")
    @SerializedName("vendedor_id")
    @Expose
    private Integer vendedor_id;

    @DatabaseField(columnName = "propietario_id")
    @SerializedName("propietario_id")
    @Expose
    private Integer propietario_id;

    @DatabaseField(columnName = "persona_contacto_id")
    @SerializedName("persona_contacto_id")
    @Expose
    private Integer persona_contacto_id;

    @DatabaseField(columnName = "direccion_facturacion_id")
    @SerializedName("direccion_facturacion_id")
    @Expose
    private Integer direccion_facturacion_id;

    @DatabaseField(columnName = "direccion_envio_id")
    @SerializedName("direccion_envio_id")
    @Expose
    private Integer direccion_envio_id;

    @DatabaseField(columnName = "latitud")
    @SerializedName("latitud")
    @Expose
    private Double latitud;

    @DatabaseField(columnName = "longitud")
    @SerializedName("longitud")
    @Expose
    private Double longitud;

    @DatabaseField(columnName = "frecuencia")
    @SerializedName("frecuencia")
    @Expose
    private Character frecuencia;

    @DatabaseField(columnName = "ruta_id")
    @SerializedName("ruta_id")
    @Expose
    private Integer ruta_id;

    @DatabaseField(columnName = "orden_ruta")
    @SerializedName("orden_ruta")
    @Expose
    private Integer orden_ruta;

    @DatabaseField(columnName = "codigo")
    @SerializedName("codigo")
    @Expose
    private String codigo;

    @DatabaseField(columnName = "tipo")
    @SerializedName("tipo")
    @Expose
    private Character tipo;

    @DatabaseField(columnName = "nombre")
    @SerializedName("nombre")
    @Expose
    private String nombre;

    @DatabaseField(columnName = "nombre_comercial")
    @SerializedName("nombre_comercial")
    @Expose
    private String nombre_comercial;

    @DatabaseField(columnName = "rfc")
    @SerializedName("rfc")
    @Expose
    private String rfc;

    @DatabaseField(columnName = "curp")
    @SerializedName("curp")
    @Expose
    private String curp;

    @DatabaseField(columnName = "telefono")
    @SerializedName("telefono")
    @Expose
    private String telefono;

    @DatabaseField(columnName = "telefono2")
    @SerializedName("telefono2")
    @Expose
    private String telefono2;

    @DatabaseField(columnName = "celular")
    @SerializedName("celular")
    @Expose
    private String celular;

    @DatabaseField(columnName = "correo")
    @SerializedName("correo")
    @Expose
    private String correo;

    @DatabaseField(columnName = "sitio_web")
    @SerializedName("sitio_web")
    @Expose
    private String sitio_web;

    @DatabaseField(columnName = "imagen")
    @SerializedName("imagen")
    @Expose
    private String imagen;

    @DatabaseField(columnName = "balance")
    @SerializedName("balance")
    @Expose
    private Double balance;

    @DatabaseField(columnName = "porcentaje_interes_retraso")
    @SerializedName("porcentaje_interes_retraso")
    @Expose
    private Double porcentaje_interes_retraso;

    @DatabaseField(columnName = "porcentaje_descuento")
    @SerializedName("porcentaje_descuento")
    @Expose
    private Double porcentaje_descuento;

    @DatabaseField(columnName = "limite_credito")
    @SerializedName("limite_credito")
    @Expose
    private Double limite_credito;

    @DatabaseField(columnName = "cuenta")
    @SerializedName("cuenta")
    @Expose
    private String cuenta;

    @DatabaseField(columnName = "cuenta_pago")
    @SerializedName("cuenta_pago")
    @Expose
    private String cuenta_pago;

    @DatabaseField(columnName = "orden_compra")
    @SerializedName("orden_compra")
    @Expose
    private Boolean orden_compra;

    @DatabaseField(columnName = "multiplicador_puntos")
    @SerializedName("multiplicador_puntos")
    @Expose
    private Double multiplicador_puntos;

    @DatabaseField(columnName = "uso_principal")
    @SerializedName("uso_principal")
    @Expose
    private String uso_principal;

    @DatabaseField(columnName = "eventual")
    @SerializedName("eventual")
    @Expose
    private Boolean eventual;

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

    public static Dao Socios()
    {
        try {
            return MainActivity.db.Socios();
        } catch (Exception ex) {
            return null;
        }
    }

    public Socio()
    {
        lista_precio_id = Global.getConfiguracion().getLista_precio_id();
        moneda_id = Global.getConfiguracion().getMoneda_id();
        condicion_pago_id = Global.getConfiguracion().getCondicion_pago_id();
        metodo_pago_id = Global.getConfiguracion().getMetodo_pago_id();
        vendedor_id = Global.getUsuario().getVendedor_id();
        tipo = 'C';
        rfc =  "XAXX010101000";
        orden_compra = false;
        uso_principal = "P01";
        activo = true;
        usuario_creacion_id = Global.getUsuario().getId();
        fecha_creacion = Functions.getCurrentDateTime();
        usuario_actualizacion_id = Global.getUsuario().getId();
        fecha_actualizacion = Functions.getCurrentDateTime();
    }

    public Boolean Agregar()
    {
        try {
            Socios().create(this);
            return true;
        }
        catch (Exception ex) {
            Global.setError(ex);
            return false;
        }
    }

    public static Socio Obtener(Integer id)
    {
        try
        {
            return (Socio) Socios().queryForId(id);
        } catch (Exception ex) {
            Global.setError(ex);
            return null;
        }
    }

    public static Socio Obtener(String codigo)
    {
        try
        {
            return (Socio) Socios().queryBuilder().where().eq("codigo", codigo).queryForFirst();
        } catch (Exception ex) {
            Global.setError(ex);
            return null;
        }
    }

    public static List<Socio> Listar()
    {
        try {
            return (List<Socio>) Socios().queryForAll();
        }
        catch (Exception ex) {
            Global.setError(ex);
            return null;
        }
    }

    public static List<Socio> ListarPorVendedor(int vendedor_id)
    {
        try {
            return (List<Socio>) Socios().queryForEq("vendedor_id", vendedor_id);
        }
        catch (Exception ex) {
            Global.setError(ex);
            return null;
        }
    }

    public static List<Socio> ListarPorRuta()
    {
        try {
            int ruta_id = Vendedor.Obtener(Global.getUsuario().getVendedor_id()).getRuta_id();
            return (List<Socio>) Socios().queryForEq("ruta_id", ruta_id);
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
            Socios().update(this);
            return true;
        }
        catch (Exception ex) {
            Global.setError(ex);
            return false;
        }
    }

    public static void SincronizarAsync(String fecha)
    {
        MainActivity.api.socios(fecha).enqueue(new Callback<List<Socio>>() {
            @Override
            public void onResponse(Call<List<Socio>> call, Response<List<Socio>> response) {
                if(response.isSuccessful()) {
                    List<Socio> socios = response.body();
                    for (Socio socio : socios) {
                        try {
                            if (Socio.Obtener(socio.id) == null) {
                                socio.Agregar();
                            } else {
                                socio.Actualizar();
                            }

                            socio.SincronizarDireccionesAsync();
                        } catch (Exception ex) {
                            Global.setError(ex);
                            continue;
                        }
                    }
                }
            }

            @Override
            public void onFailure(Call<List<Socio>> call, Throwable t) {
                //
            }
        });
    }

    public static void Sincronizar(String fecha)
    {
        try {
            List<Socio> socios = MainActivity.api.socios(fecha).execute().body();
            int restantes = socios.size();
            for (Socio socio : socios) {
                try {
                    if (Socio.Obtener(socio.id) == null) {
                        socio.Agregar();
                    } else {
                        socio.Actualizar();
                    }

                    socio.SincronizarDirecciones();

                    Nori.estado = "Socios restantes: " + restantes;
                    restantes--;
                } catch (Exception ex) {
                    Global.setError(ex);
                    continue;
                }
            }
            FechaSincronizacion.Obtener("socios").Actualizar();
        } catch (Exception ex) {
            Global.setError(ex);
        } finally {
            Global.setSincronizando(false);
        }
    }

    public void SincronizarDireccionesAsync()
    {
        MainActivity.api.socios_direcciones(id).enqueue(new Callback<List<Socio.Direccion>>() {
            @Override
            public void onResponse(Call<List<Socio.Direccion>> call, Response<List<Socio.Direccion>> response) {
                if(response.isSuccessful()) {
                    List<Socio.Direccion> direcciones = response.body();
                    for (Socio.Direccion direccion : direcciones) {
                        try {
                            if (Socio.Direccion.Obtener(direccion.id) == null) {
                                direccion.Agregar();
                            } else {
                                direccion.Actualizar();
                            }
                        } catch (Exception ex) {
                            Global.setError(ex);
                            continue;
                        }
                    }
                }
            }

            @Override
            public void onFailure(Call<List<Socio.Direccion>> call, Throwable t) {
                //
            }
        });
    }

    public void SincronizarDirecciones()
    {
        try {
            List<Socio.Direccion> direcciones = MainActivity.api.socios_direcciones(id).execute().body();
            for (Socio.Direccion direccion : direcciones) {
                try {
                    if (Socio.Direccion.Obtener(direccion.id) == null) {
                        direccion.Agregar();
                    } else {
                        direccion.Actualizar();
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

    public Integer getMoneda_id() {
        return moneda_id;
    }

    public void setMoneda_id(Integer moneda_id) {
        this.moneda_id = moneda_id;
    }

    public Integer getCondicion_pago_id() {
        return condicion_pago_id;
    }

    public void setCondicion_pago_id(Integer condicion_pago_id) {
        this.condicion_pago_id = condicion_pago_id;
    }

    public Integer getGrupo_socio_id() {
        return grupo_socio_id;
    }

    public void setGrupo_socio_id(Integer grupo_socio_id) {
        this.grupo_socio_id = grupo_socio_id;
    }

    public Integer getMetodo_pago_id() {
        return metodo_pago_id;
    }

    public void setMetodo_pago_id(Integer metodo_pago_id) {
        this.metodo_pago_id = metodo_pago_id;
    }

    public Integer getVendedor_id() {
        return vendedor_id;
    }

    public void setVendedor_id(Integer vendedor_id) {
        this.vendedor_id = vendedor_id;
    }

    public Integer getPersona_contacto_id() {
        return persona_contacto_id;
    }

    public void setPersona_contacto_id(Integer persona_contacto_id) {
        this.persona_contacto_id = persona_contacto_id;
    }

    public Integer getDireccion_facturacion_id() {
        return direccion_facturacion_id;
    }

    public void setDireccion_facturacion_id(Integer direccion_facturacion_id) {
        this.direccion_facturacion_id = direccion_facturacion_id;
    }

    public Integer getDireccion_envio_id() {
        return direccion_envio_id;
    }

    public void setDireccion_envio_id(Integer direccion_envio_id) {
        this.direccion_envio_id = direccion_envio_id;
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

    public Integer getPropietario_id() {
        return propietario_id;
    }

    public void setPropietario_id(Integer propietario_id) {
        this.propietario_id = propietario_id;
    }

    public Character getFrecuencia() {
        return frecuencia;
    }

    public void setFrecuencia(Character frecuencia) {
        this.frecuencia = frecuencia;
    }

    public Integer getRuta_id() {
        return ruta_id;
    }

    public void setRuta_id(Integer ruta_id) {
        this.ruta_id = ruta_id;
    }

    public Integer getOrden_ruta() {
        return orden_ruta;
    }

    public void setOrden_ruta(Integer orden_ruta) {
        this.orden_ruta = orden_ruta;
    }

    public String getCodigo() {
        return codigo;
    }

    public void setCodigo(String codigo) {
        this.codigo = codigo;
    }

    public Character getTipo() {
        return tipo;
    }

    public void setTipo(Character tipo) {
        this.tipo = tipo;
    }

    public String getNombre() {
        return nombre;
    }

    public void setNombre(String nombre) {
        this.nombre = nombre;
    }

    public String getNombre_comercial() {
        return nombre_comercial;
    }

    public void setNombre_comercial(String nombre_comercial) {
        this.nombre_comercial = nombre_comercial;
    }

    public String getRfc() {
        return rfc;
    }

    public void setRfc(String rfc) {
        this.rfc = rfc;
    }

    public String getCurp() {
        return curp;
    }

    public void setCurp(String curp) {
        this.curp = curp;
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

    public String getCelular() {
        return celular;
    }

    public void setCelular(String celular) {
        this.celular = celular;
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

    public String getImagen() {
        return imagen;
    }

    public void setImagen(String imagen) {
        this.imagen = imagen;
    }

    public Double getBalance() {
        return balance;
    }

    public void setBalance(Double balance) {
        this.balance = balance;
    }

    public Double getPorcentaje_interes_retraso() {
        return porcentaje_interes_retraso;
    }

    public void setPorcentaje_interes_retraso(Double porcentaje_interes_retraso) {
        this.porcentaje_interes_retraso = porcentaje_interes_retraso;
    }

    public Double getPorcentaje_descuento() {
        return porcentaje_descuento;
    }

    public void setPorcentaje_descuento(Double porcentaje_descuento) {
        this.porcentaje_descuento = porcentaje_descuento;
    }

    public Double getLimite_credito() {
        return limite_credito;
    }

    public void setLimite_credito(Double limite_credito) {
        this.limite_credito = limite_credito;
    }

    public String getCuenta() {
        return cuenta;
    }

    public void setCuenta(String cuenta) {
        this.cuenta = cuenta;
    }

    public String getCuenta_pago() {
        return cuenta_pago;
    }

    public void setCuenta_pago(String cuenta_pago) {
        this.cuenta_pago = cuenta_pago;
    }

    public Boolean getOrden_compra() {
        return orden_compra;
    }

    public void setOrden_compra(Boolean orden_compra) {
        this.orden_compra = orden_compra;
    }

    public Double getMultiplicador_puntos() {
        return multiplicador_puntos;
    }

    public void setMultiplicador_puntos(Double multiplicador_puntos) {
        this.multiplicador_puntos = multiplicador_puntos;
    }

    public String getUso_principal() {
        return uso_principal;
    }

    public void setUso_principal(String uso_principal) {
        this.uso_principal = uso_principal;
    }

    public Boolean getEventual() {
        return eventual;
    }

    public void setEventual(Boolean eventual) {
        this.eventual = eventual;
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

    @DatabaseTable(tableName = "direcciones")
    public static class Direccion {
        @DatabaseField(columnName = "id", id = true, unique = true)
        @SerializedName("id")
        @Expose
        private Integer id;

        @DatabaseField(columnName = "socio_id")
        @SerializedName("socio_id")
        @Expose
        private Integer socio_id;

        @DatabaseField(columnName = "impuesto_id")
        @SerializedName("impuesto_id")
        @Expose
        private Integer impuesto_id;

        @DatabaseField(columnName = "nombre")
        @SerializedName("nombre")
        @Expose
        private String nombre;

        @DatabaseField(columnName = "tipo")
        @SerializedName("tipo")
        @Expose
        private Character tipo;

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

        @DatabaseField(columnName = "estado_id")
        @SerializedName("estado_id")
        @Expose
        private Integer estado_id;

        @DatabaseField(columnName = "pais_id")
        @SerializedName("pais_id")
        @Expose
        private Integer pais_id;

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

        public static Dao Direcciones()
        {
            try {
                return MainActivity.db.Direcciones();
            } catch (Exception ex) {
                return null;
            }
        }

        public Direccion()
        {
            usuario_creacion_id = Global.getUsuario().getId();
            fecha_creacion = Functions.getCurrentDateTime();
            usuario_actualizacion_id = Global.getUsuario().getId();
            fecha_actualizacion = Functions.getCurrentDateTime();
        }

        public Boolean Agregar()
        {
            try {
                Direcciones().create(this);
                return true;
            }
            catch (Exception ex) {
                Global.setError(ex);
                return false;
            }
        }

        public static Direccion Obtener(Integer id)
        {
            try
            {
                return (Direccion) Direcciones().queryForId(id);
            } catch (Exception ex) {
                Global.setError(ex);
                return null;
            }
        }

        public static Direccion Obtener(Integer socio_id, String nombre)
        {
            try
            {
                return (Direccion) Direcciones().queryBuilder().where().eq("socio_id", socio_id).and().eq("nombre", nombre).queryForFirst();
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
                Direcciones().update(this);
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

        public Integer getSocio_id() {
            return socio_id;
        }

        public void setSocio_id(Integer socio_id) {
            this.socio_id = socio_id;
        }

        public Integer getImpuesto_id() {
            return impuesto_id;
        }

        public void setImpuesto_id(Integer impuesto_id) {
            this.impuesto_id = impuesto_id;
        }

        public String getNombre() {
            return nombre;
        }

        public void setNombre(String nombre) {
            this.nombre = nombre;
        }

        public Character getTipo() {
            return tipo;
        }

        public void setTipo(Character tipo) {
            this.tipo = tipo;
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

        public Integer getEstado_id() {
            return estado_id;
        }

        public void setEstado_id(Integer estado_id) {
            this.estado_id = estado_id;
        }

        public Integer getPais_id() {
            return pais_id;
        }

        public void setPais_id(Integer pais_id) {
            this.pais_id = pais_id;
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