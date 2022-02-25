package mx.nori.nori.NoriSDK;

import com.google.gson.annotations.Expose;
import com.google.gson.annotations.SerializedName;

import java.util.ArrayList;
import java.util.Date;
import java.util.List;

import com.j256.ormlite.dao.Dao;
import com.j256.ormlite.field.DatabaseField;
import com.j256.ormlite.table.DatabaseTable;

import mx.nori.nori.Functions;
import mx.nori.nori.MainActivity;
import mx.nori.nori.Nori;
import retrofit2.Call;
import retrofit2.Callback;
import retrofit2.Response;

@DatabaseTable(tableName = "articulos")
public class Articulo {
    @DatabaseField(columnName = "id", id = true, unique = true)
    @SerializedName("id")
    @Expose
    private Integer id;

    @DatabaseField(columnName = "grupo_articulo_id")
    @SerializedName("grupo_articulo_id")
    @Expose
    private Integer grupo_articulo_id;

    @DatabaseField(columnName = "unidad_medida_id")
    @SerializedName("unidad_medida_id")
    @Expose
    private Integer unidad_medida_id;

    @DatabaseField(columnName = "fabricante_id")
    @SerializedName("fabricante_id")
    @Expose
    private Integer fabricante_id;

    @DatabaseField(columnName = "socio_id")
    @SerializedName("socio_id")
    @Expose
    private Integer socio_id;

    @DatabaseField(columnName = "almacen_id")
    @SerializedName("almacen_id")
    @Expose
    private Integer almacen_id;

    @DatabaseField(columnName = "tipo_empaque_id")
    @SerializedName("tipo_empaque_id")
    @Expose
    private Integer tipo_empaque_id;

    @DatabaseField(columnName = "almacenable")
    @SerializedName("almacenable")
    @Expose
    private Boolean almacenable;

    @DatabaseField(columnName = "venta")
    @SerializedName("venta")
    @Expose
    private Boolean venta;

    @DatabaseField(columnName = "compra")
    @SerializedName("compra")
    @Expose
    private Boolean compra;

    @DatabaseField(columnName = "canjeable")
    @SerializedName("canjeable")
    @Expose
    private Boolean canjeable;

    @DatabaseField(columnName = "seguimiento")
    @SerializedName("seguimiento")
    @Expose
    private Character seguimiento;

    @DatabaseField(columnName = "dias_garantia")
    @SerializedName("dias_garantia")
    @Expose
    private Short dias_garantia;

    @DatabaseField(columnName = "sku")
    @SerializedName("sku")
    @Expose
    private String sku;

    @DatabaseField(columnName = "sku_fabricante")
    @SerializedName("sku_fabricante")
    @Expose
    private String sku_fabricante;

    @DatabaseField(columnName = "id_adicional")
    @SerializedName("id_adicional")
    @Expose
    private String id_adicional;

    @DatabaseField(columnName = "codigo_clasificacion")
    @SerializedName("codigo_clasificacion")
    @Expose
    private String codigo_clasificacion;

    @DatabaseField(columnName = "nombre")
    @SerializedName("nombre")
    @Expose
    private String nombre;

    @DatabaseField(columnName = "nombre_api")
    @SerializedName("nombre_api")
    @Expose
    private String nombre_api;

    @DatabaseField(columnName = "descripcion")
    @SerializedName("descripcion")
    @Expose
    private String descripcion;

    @DatabaseField(columnName = "clave_unidad")
    @SerializedName("clave_unidad")
    @Expose
    private String clave_unidad;

    @DatabaseField(columnName = "imagen")
    @SerializedName("imagen")
    @Expose
    private String imagen;

    @DatabaseField(columnName = "codigo_barras")
    @SerializedName("codigo_barras")
    @Expose
    private String codigo_barras;

    @DatabaseField(columnName = "peso")
    @SerializedName("peso")
    @Expose
    private Double peso;

    @DatabaseField(columnName = "cantidad_paquete")
    @SerializedName("cantidad_paquete")
    @Expose
    private Double cantidad_paquete;

    @DatabaseField(columnName = "pesable")
    @SerializedName("pesable")
    @Expose
    private Boolean pesable;

    @DatabaseField(columnName = "ajuste_maximo")
    @SerializedName("ajuste_maximo")
    @Expose
    private Double ajuste_maximo;

    @DatabaseField(columnName = "ajuste_minimo")
    @SerializedName("ajuste_minimo")
    @Expose
    private Double ajuste_minimo;

    //Impuestos
    @DatabaseField(columnName = "sujeto_retencion")
    @SerializedName("sujeto_retencion")
    @Expose
    private Boolean sujeto_retencion;

    @DatabaseField(columnName = "sujeto_impuesto")
    @SerializedName("sujeto_impuesto")
    @Expose
    private Boolean sujeto_impuesto;

    @DatabaseField(columnName = "ieps")
    @SerializedName("ieps")
    @Expose
    private Boolean ieps;

    @DatabaseField(columnName = "impuesto_compra_id")
    @SerializedName("impuesto_compra_id")
    @Expose
    private Integer impuesto_compra_id;

    @DatabaseField(columnName = "impuesto_venta_id")
    @SerializedName("impuesto_venta_id")
    @Expose
    private Integer impuesto_venta_id;

    //Impuestos
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

    public static Dao Articulos()
    {
        try {
            return MainActivity.db.Articulos();
        } catch (Exception ex) {
            return null;
        }
    }

    public Articulo()
    {
        fecha_creacion = Functions.getCurrentDateTime();
        fecha_actualizacion = Functions.getCurrentDateTime();
    }

    public Boolean Agregar()
    {
        try {
            Articulos().create(this);
            return true;
        }
        catch (Exception ex) {
            Global.setError(ex);
            return false;
        }
    }

    public static Articulo Obtener(Integer id)
    {
        try
        {
            return (Articulo) Articulos().queryForId(id);
        } catch (Exception ex) {
            Global.setError(ex);
            return null;
        }
    }

    public static Articulo Obtener(String sku)
    {
        try {
            return (Articulo) Articulos().queryBuilder().where().eq("sku", sku).queryForFirst();
        }
        catch (Exception ex) {
            Global.setError(ex);
            return null;
        }
    }

    public static List<Articulo> Listar()
    {
        try {
            return (List<Articulo>) Articulos().queryForAll();
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
            Articulos().update(this);
            return true;
        }
        catch (Exception ex) {
            Global.setError(ex);
            return false;
        }
    }

    public static void SincronizarAsync(String fecha)
    {
        MainActivity.api.articulos(fecha).enqueue(new Callback<List<Articulo>>() {
            @Override
            public void onResponse(Call<List<Articulo>> call, Response<List<Articulo>> response) {
                if(response.isSuccessful()) {
                    List<Articulo> articulos = response.body();
                    for (Articulo articulo : articulos) {
                        try {
                            if (Articulo.Obtener(articulo.id) == null) {
                                articulo.Agregar();
                            } else {
                                articulo.Actualizar();
                            }

                            articulo.SincronizarPreciosAsync();
                            articulo.SincronizarCodigosBarrasAsync();
                            if (articulo.almacenable)
                            {
                                articulo.SincronizarInventarioAsync();
                            }
                        } catch (Exception ex) {
                            Global.setError(ex);
                            continue;
                        }
                    }
                }
            }

            @Override
            public void onFailure(Call<List<Articulo>> call, Throwable t) {
                //
            }
        });
    }

    public static boolean Sincronizar(String fecha)
    {
        try {
            List<Articulo> articulos = MainActivity.api.articulos(fecha).execute().body();
            int restantes = articulos.size();
            for (Articulo articulo : articulos) {
                try {
                    if (Articulo.Obtener(articulo.id) == null) {
                        articulo.Agregar();
                    } else {
                        articulo.Actualizar();
                    }

                    articulo.SincronizarPrecios();
                    articulo.SincronizarCodigosBarras();
                    if (articulo.almacenable)
                    {
                        articulo.SincronizarInventario();
                    }
                } catch (Exception ex) {
                    Global.setError(ex);
                    continue;
                }

                Nori.estado = "Artículos restantes: " + restantes;
                restantes--;
            }
            FechaSincronizacion.Obtener("articulos").Actualizar();
            return true;
        } catch (Exception ex) {
            Global.setError(ex);
            return false;
        } finally {
            Global.setSincronizando(false);
        }
    }

    public List<Precio> Precios()
    {
        try
        {
            return Precio.Precios().queryForEq("articulo_id", id);
        } catch (Exception ex) {
            Global.setError(ex);
            return null;
        }
    }

    public void SincronizarPreciosAsync()
    {
        MainActivity.api.articulo_precios(id).enqueue(new Callback<List<Articulo.Precio>>() {
            @Override
            public void onResponse(Call<List<Articulo.Precio>> call, Response<List<Articulo.Precio>> response) {
                if(response.isSuccessful()) {
                    List<Articulo.Precio> precios = response.body();
                    for (Articulo.Precio precio : precios) {
                        try {
                            if (Articulo.Precio.Obtener(precio.id) == null) {
                                precio.Agregar();
                            } else {
                                precio.Actualizar();
                            }
                        } catch (Exception ex) {
                            Global.setError(ex);
                            continue;
                        }
                    }
                }
            }

            @Override
            public void onFailure(Call<List<Articulo.Precio>> call, Throwable t) {
                //
            }
        });
    }

    public boolean SincronizarPrecios()
    {
        try {
            List<Articulo.Precio> precios = MainActivity.api.articulo_precios(id).execute().body();
            for (Articulo.Precio precio : precios) {
                try {
                    if (Articulo.Precio.Obtener(precio.id) == null) {
                        precio.Agregar();
                    } else {
                        precio.Actualizar();
                    }
                } catch (Exception ex) {
                    Global.setError(ex);
                    continue;
                }
            }

            return true;
        } catch (Exception ex) {
            Global.setError(ex);
            return false;
        }
    }

    public List<CodigoBarras> CodigosBarras()
    {
        try
        {
            return CodigoBarras.CodigosBarras().queryForEq("articulo_id", id);
        } catch (Exception ex) {
            Global.setError(ex);
            return null;
        }
    }

    public void SincronizarCodigosBarrasAsync()
    {
        MainActivity.api.articulo_codigos_barras(id).enqueue(new Callback<List<Articulo.CodigoBarras>>() {
            @Override
            public void onResponse(Call<List<Articulo.CodigoBarras>> call, Response<List<Articulo.CodigoBarras>> response) {
                if(response.isSuccessful()) {
                    List<Articulo.CodigoBarras> codigos_barras = response.body();
                    for (Articulo.CodigoBarras codigo_barras : codigos_barras) {
                        try {
                            if (Articulo.CodigoBarras.Obtener(codigo_barras.id) == null) {
                                codigo_barras.Agregar();
                            } else {
                                codigo_barras.Actualizar();
                            }
                        } catch (Exception ex) {
                            Global.setError(ex);
                            continue;
                        }
                    }
                }
            }

            @Override
            public void onFailure(Call<List<Articulo.CodigoBarras>> call, Throwable t) {
                //
            }
        });
    }

    public boolean SincronizarCodigosBarras()
    {
        try {
            List<Articulo.CodigoBarras> codigos_barras = MainActivity.api.articulo_codigos_barras(id).execute().body();
            for (Articulo.CodigoBarras codigo_barras : codigos_barras) {
                try {
                    if (Articulo.CodigoBarras.Obtener(codigo_barras.id) == null) {
                        codigo_barras.Agregar();
                    } else {
                        codigo_barras.Actualizar();
                    }
                } catch (Exception ex) {
                    Global.setError(ex);
                    continue;
                }
            }

            return true;
        } catch (Exception ex) {
            Global.setError(ex);
            return false;
        }
    }

    public List<Inventario> Inventario()
    {
        try
        {
            return Inventario.Inventarios().queryForEq("articulo_id", id);
        } catch (Exception ex) {
            Global.setError(ex);
            return null;
        }
    }

    public void SincronizarInventarioAsync()
    {
        MainActivity.api.articulo_inventario(id, Global.getUsuario().getAlmacen_id()).enqueue(new Callback<List<Articulo.Inventario>>() {
            @Override
            public void onResponse(Call<List<Articulo.Inventario>> call, Response<List<Articulo.Inventario>> response) {
                if(response.isSuccessful()) {
                    List<Articulo.Inventario> inventarios = response.body();
                    for (Articulo.Inventario inventario : inventarios) {
                        try {
                            if (Articulo.Inventario.Obtener(inventario.id) == null) {
                                inventario.Agregar();
                            } else {
                                inventario.Actualizar();
                            }
                        } catch (Exception ex) {
                            Global.setError(ex);
                            continue;
                        }
                    }
                }
            }

            @Override
            public void onFailure(Call<List<Articulo.Inventario>> call, Throwable t) {
                //
            }
        });
    }

    public boolean SincronizarInventario()
    {
        try {
            List<Articulo.Inventario> inventarios = MainActivity.api.articulo_inventario(id, Global.getUsuario().getAlmacen_id()).execute().body();
            for (Articulo.Inventario inventario : inventarios) {
                try {
                    if (Articulo.Inventario.Obtener(inventario.id) == null) {
                        inventario.Agregar();
                    } else {
                        inventario.Actualizar();
                    }
                } catch (Exception ex) {
                    Global.setError(ex);
                    continue;
                }
            }

            return true;
        } catch (Exception ex) {
            Global.setError(ex);
            return false;
        }
    }

    //Funciones
    public static Impuesto ObtenerImpuesto(Integer articulo_id, Integer socio_id) {
        try {
            Impuesto impueto = new Impuesto();
            Articulo articulo = Articulo.Obtener(articulo_id);
            Socio socio = Socio.Obtener(socio_id);

            if (articulo.sujeto_impuesto) {
                if (articulo.impuesto_compra_id != 0 && socio.getTipo().equals('P')) {
                    return Impuesto.Obtener(articulo.impuesto_compra_id);
                } else if (articulo.impuesto_venta_id != 0 && socio.getTipo().equals('C')) {
                    return Impuesto.Obtener(articulo.impuesto_venta_id);
                }

                if (socio.getDireccion_envio_id() != 0) {
                    Socio.Direccion direccion = Socio.Direccion.Obtener(socio.getDireccion_envio_id());
                    if (direccion != null) {
                        return Impuesto.Obtener(direccion.getImpuesto_id());
                    }
                }

                if (Global.getConfiguracion().getImpuesto_id() != 0) {
                    return Impuesto.Obtener(Global.getConfiguracion().getImpuesto_id());
                }
            }

            return  impueto;
        } catch (Exception ex) {
            Global.setError(ex);
            return null;
        }
    }

    public Integer getId() {
        return id;
    }

    public void setId(Integer id) {
        this.id = id;
    }

    public Integer getGrupo_articulo_id() {
        return grupo_articulo_id;
    }

    public void setGrupo_articulo_id(Integer grupo_articulo_id) {
        this.grupo_articulo_id = grupo_articulo_id;
    }

    public Integer getUnidad_medida_id() {
        return unidad_medida_id;
    }

    public void setUnidad_medida_id(Integer unidad_medida_id) {
        this.unidad_medida_id = unidad_medida_id;
    }

    public Integer getFabricante_id() {
        return fabricante_id;
    }

    public void setFabricante_id(Integer fabricante_id) {
        this.fabricante_id = fabricante_id;
    }

    public Integer getSocio_id() {
        return socio_id;
    }

    public void setSocio_id(Integer socio_id) {
        this.socio_id = socio_id;
    }

    public Integer getAlmacen_id() {
        return almacen_id;
    }

    public void setAlmacen_id(Integer almacen_id) {
        this.almacen_id = almacen_id;
    }

    public Integer getTipo_empaque_id() {
        return tipo_empaque_id;
    }

    public void setTipo_empaque_id(Integer tipo_empaque_id) {
        this.tipo_empaque_id = tipo_empaque_id;
    }

    public Boolean getAlmacenable() {
        return almacenable;
    }

    public void setAlmacenable(Boolean almacenable) {
        this.almacenable = almacenable;
    }

    public Boolean getVenta() {
        return venta;
    }

    public void setVenta(Boolean venta) {
        this.venta = venta;
    }

    public Boolean getCompra() {
        return compra;
    }

    public void setCompra(Boolean compra) {
        this.compra = compra;
    }

    public Boolean getCanjeable() {
        return canjeable;
    }

    public void setCanjeable(Boolean canjeable) {
        this.canjeable = canjeable;
    }

    public Character getSeguimiento() {
        return seguimiento;
    }

    public void setSeguimiento(Character seguimiento) {
        this.seguimiento = seguimiento;
    }

    public Short getDias_garantia() {
        return dias_garantia;
    }

    public void setDias_garantia(Short dias_garantia) {
        this.dias_garantia = dias_garantia;
    }

    public String getSku() {
        return sku;
    }

    public void setSku(String sku) {
        this.sku = sku;
    }

    public String getSku_fabricante() {
        return sku_fabricante;
    }

    public void setSku_fabricante(String sku_fabricante) {
        this.sku_fabricante = sku_fabricante;
    }

    public String getId_adicional() {
        return id_adicional;
    }

    public void setId_adicional(String id_adicional) {
        this.id_adicional = id_adicional;
    }

    public String getCodigo_clasificacion() {
        return codigo_clasificacion;
    }

    public void setCodigo_clasificacion(String codigo_clasificacion) {
        this.codigo_clasificacion = codigo_clasificacion;
    }

    public String getNombre() {
        if (nombre_api != null) {
            if (nombre_api.length() == 0) {
                return nombre;
            } else {
                return nombre_api;
            }
        }
        return nombre;
    }

    public void setNombre(String nombre) {
        this.nombre = nombre;
    }

    public String getNombre_api() {
        return nombre_api;
    }

    public void setNombre_api(String nombre_api) {
        this.nombre_api = nombre_api;
    }

    public String getDescripcion() {
        return descripcion;
    }

    public void setDescripcion(String descripcion) {
        this.descripcion = descripcion;
    }

    public String getClave_unidad() {
        return clave_unidad;
    }

    public void setClave_unidad(String clave_unidad) {
        this.clave_unidad = clave_unidad;
    }

    public String getImagen() {
        return imagen;
    }

    public void setImagen(String imagen) {
        this.imagen = imagen;
    }

    public String getCodigo_barras() {
        return codigo_barras;
    }

    public void setCodigo_barras(String codigo_barras) {
        this.codigo_barras = codigo_barras;
    }

    public Double getPeso() {
        return peso;
    }

    public void setPeso(Double peso) {
        this.peso = peso;
    }

    public Double getCantidad_paquete() {
        return cantidad_paquete;
    }

    public void setCantidad_paquete(Double cantidad_paquete) {
        this.cantidad_paquete = cantidad_paquete;
    }

    public Boolean getPesable() {
        return pesable;
    }

    public void setPesable(Boolean pesable) {
        this.pesable = pesable;
    }

    public Double getAjuste_maximo() {
        return ajuste_maximo;
    }

    public void setAjuste_maximo(Double ajuste_maximo) {
        this.ajuste_maximo = ajuste_maximo;
    }

    public Double getAjuste_minimo() {
        return ajuste_minimo;
    }

    public void setAjuste_minimo(Double ajuste_minimo) {
        this.ajuste_minimo = ajuste_minimo;
    }

    public Boolean getSujeto_retencion() {
        return sujeto_retencion;
    }

    public void setSujeto_retencion(Boolean sujeto_retencion) {
        this.sujeto_retencion = sujeto_retencion;
    }

    public Boolean getSujeto_impuesto() {
        return sujeto_impuesto;
    }

    public void setSujeto_impuesto(Boolean sujeto_impuesto) {
        this.sujeto_impuesto = sujeto_impuesto;
    }

    public Boolean getIeps() {
        return ieps;
    }

    public void setIeps(Boolean ieps) {
        this.ieps = ieps;
    }

    public Integer getImpuesto_compra_id() {
        return impuesto_compra_id;
    }

    public void setImpuesto_compra_id(Integer impuesto_compra_id) {
        this.impuesto_compra_id = impuesto_compra_id;
    }

    public Integer getImpuesto_venta_id() {
        return impuesto_venta_id;
    }

    public void setImpuesto_venta_id(Integer impuesto_venta_id) {
        this.impuesto_venta_id = impuesto_venta_id;
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

    @DatabaseTable(tableName = "precios")
    public static class Precio {
        @DatabaseField(columnName = "id", id = true, unique = true)
        @SerializedName("id")
        @Expose
        private Integer id;

        @DatabaseField(columnName = "articulo_id")
        @SerializedName("articulo_id")
        @Expose
        private Integer articulo_id;

        @DatabaseField(columnName = "unidad_medida_id")
        @SerializedName("unidad_medida_id")
        @Expose
        private Integer unidad_medida_id;

        @DatabaseField(columnName = "lista_precio_id")
        @SerializedName("lista_precio_id")
        @Expose
        private Integer lista_precio_id;

        @DatabaseField(columnName = "moneda_id")
        @SerializedName("moneda_id")
        @Expose
        private Integer moneda_id;

        @DatabaseField(columnName = "precio")
        @SerializedName("precio")
        @Expose
        private Double precio;

        @DatabaseField(columnName = "multiplicador_puntos")
        @SerializedName("multiplicador_puntos")
        @Expose
        private Double multiplicador_puntos;

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

        public static Dao Precios()
        {
            try {
                return MainActivity.db.Precios();
            } catch (Exception ex) {
                return null;
            }
        }

        public Precio()
        {
            fecha_creacion = Functions.getCurrentDateTime();
            fecha_actualizacion = Functions.getCurrentDateTime();
        }

        public Boolean Agregar()
        {
            try {
                Precios().create(this);
                return true;
            }
            catch (Exception ex) {
                Global.setError(ex);
                return false;
            }
        }

        public static Precio Obtener(Integer id)
        {
            try
            {
                return (Precio) Precios().queryForId(id);
            } catch (Exception ex) {
                Global.setError(ex);
                return null;
            }
        }

        public static Precio Obtener2(Integer articulo_id, Integer lista_precio_id)
        {
            try
            {
                return (Precio) Precios().queryBuilder().where().eq("articulo_id", articulo_id).and().eq("lista_precio_id", lista_precio_id).queryForFirst();
            } catch (Exception ex) {
                Global.setError(ex);
                return null;
            }
        }

        public static Precio Obtener(Integer articulo_id, Integer lista_precio_id, Integer unidad_medida_id)
        {
            try
            {
                return (Precio) Precios().queryBuilder().where().eq("articulo_id", articulo_id).and().eq("lista_precio_id", lista_precio_id).and().eq("unidad_medida_id", unidad_medida_id).queryForFirst();
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
                Precios().update(this);
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

        public Integer getArticulo_id() {
            return articulo_id;
        }

        public void setArticulo_id(Integer articulo_id) {
            this.articulo_id = articulo_id;
        }

        public Integer getUnidad_medida_id() {
            return unidad_medida_id;
        }

        public void setUnidad_medida_id(Integer unidad_medida_id) {
            this.unidad_medida_id = unidad_medida_id;
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

        public Double getPrecio() {
            return precio;
        }

        public void setPrecio(Double precio) {
            this.precio = precio;
        }

        public Double getMultiplicador_puntos() {
            return multiplicador_puntos;
        }

        public void setMultiplicador_puntos(Double multiplicador_puntos) {
            this.multiplicador_puntos = multiplicador_puntos;
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

    @DatabaseTable(tableName = "codigos_barras")
    public static class CodigoBarras {
        @DatabaseField(columnName = "id", id = true, unique = true)
        @SerializedName("id")
        @Expose
        private Integer id;

        @DatabaseField(columnName = "articulo_id")
        @SerializedName("articulo_id")
        @Expose
        private Integer articulo_id;

        @DatabaseField(columnName = "unidad_medida_id")
        @SerializedName("unidad_medida_id")
        @Expose
        private Integer unidad_medida_id;

        @DatabaseField(columnName = "codigo")
        @SerializedName("codigo")
        @Expose
        private String codigo;

        @DatabaseField(columnName = "nombre")
        @SerializedName("nombre")
        @Expose
        private String nombre;

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

        public static Dao CodigosBarras()
        {
            try {
                return MainActivity.db.CodigosBarras();
            } catch (Exception ex) {
                return null;
            }
        }

        public CodigoBarras()
        {
            fecha_creacion = Functions.getCurrentDateTime();
            fecha_actualizacion = Functions.getCurrentDateTime();
        }

        public Boolean Agregar()
        {
            try {
                CodigosBarras().create(this);
                return true;
            }
            catch (Exception ex) {
                Global.setError(ex);
                return false;
            }
        }

        public static CodigoBarras Obtener(Integer id)
        {
            try
            {
                return (CodigoBarras) CodigosBarras().queryForId(id);
            } catch (Exception ex) {
                Global.setError(ex);
                return null;
            }
        }

        public static CodigoBarras Obtener(String codigo)
        {
            try
            {
                return (CodigoBarras) CodigosBarras().queryBuilder().where().eq("codigo", codigo).queryForFirst();
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
                CodigosBarras().update(this);
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

        public Integer getArticulo_id() {
            return articulo_id;
        }

        public void setArticulo_id(Integer articulo_id) {
            this.articulo_id = articulo_id;
        }

        public Integer getUnidad_medida_id() {
            return unidad_medida_id;
        }

        public void setUnidad_medida_id(Integer unidad_medida_id) {
            this.unidad_medida_id = unidad_medida_id;
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

    @DatabaseTable(tableName = "inventario")
    public static class Inventario
    {
        @DatabaseField(columnName = "id", id = true, unique = true)
        @SerializedName("id")
        @Expose
        private Integer id;

        @DatabaseField(columnName = "articulo_id")
        @SerializedName("articulo_id")
        @Expose
        private Integer articulo_id;

        @DatabaseField(columnName = "almacen_id")
        @SerializedName("almacen_id")
        @Expose
        private Integer almacen_id;

        @DatabaseField(columnName = "stock")
        @SerializedName("stock")
        @Expose
        private Double stock;

        @DatabaseField(columnName = "comprometido")
        @SerializedName("comprometido")
        @Expose
        private Double comprometido;

        @DatabaseField(columnName = "pedido")
        @SerializedName("pedido")
        @Expose
        private Double pedido;

        @DatabaseField(columnName = "disponible")
        @SerializedName("disponible")
        @Expose
        private Double disponible;

        @DatabaseField(columnName = "stock_minimo")
        @SerializedName("stock_minimo")
        @Expose
        private Double stock_minimo;

        @DatabaseField(columnName = "stock_maximo")
        @SerializedName("stock_maximo")
        @Expose
        private Double stock_maximo;

        @DatabaseField(columnName = "costo")
        @SerializedName("costo")
        @Expose
        private Double costo;

        @DatabaseField(columnName = "activo")
        @SerializedName("activo")
        @Expose
        private Boolean activo;

        @DatabaseField(columnName = "fecha_creacion")
        private transient Date fecha_creacion;

        @DatabaseField(columnName = "usuario_actualizacion_id")
        @SerializedName("usuario_actualizacion_id")
        @Expose
        private Integer usuario_actualizacion_id;

        @DatabaseField(columnName = "fecha_actualizacion")
        private transient Date fecha_actualizacion;

        public static Dao Inventarios()
        {
            try {
                return MainActivity.db.Inventarios();
            } catch (Exception ex) {
                return null;
            }
        }

        public Inventario()
        {
            fecha_creacion = Functions.getCurrentDateTime();
            fecha_actualizacion = Functions.getCurrentDateTime();
        }

        public Boolean Agregar()
        {
            try {
                Inventarios().create(this);
                return true;
            }
            catch (Exception ex) {
                Global.setError(ex);
                return false;
            }
        }

        public static Inventario Obtener(Integer id)
        {
            try
            {
                return (Inventario) Inventarios().queryForId(id);
            } catch (Exception ex) {
                Global.setError(ex);
                return null;
            }
        }

        public static Inventario Obtener(Integer articulo_id, Integer almacen_id)
        {
            try
            {
                return (Inventario) Inventarios().queryBuilder().where().eq("articulo_id", articulo_id).and().eq("almacen_id", almacen_id).queryForFirst();
            } catch (Exception ex) {
                Global.setError(ex);
                return null;
            }
        }

        public Boolean Actualizar()
        {
            try {
                disponible = (stock + pedido) - comprometido;
                usuario_actualizacion_id = Global.getUsuario().getId();
                fecha_actualizacion = Functions.getCurrentDateTime();
                Inventarios().update(this);
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

        public Integer getArticulo_id() {
            return articulo_id;
        }

        public void setArticulo_id(Integer articulo_id) {
            this.articulo_id = articulo_id;
        }

        public Integer getAlmacen_id() {
            return almacen_id;
        }

        public void setAlmacen_id(Integer almacen_id) {
            this.almacen_id = almacen_id;
        }

        public Double getStock() {
            return stock;
        }

        public void setStock(Double stock) {
            this.stock = stock;
        }

        public Double getComprometido() {
            return comprometido;
        }

        public void setComprometido(Double comprometido) {
            this.comprometido = comprometido;
        }

        public Double getPedido() {
            return pedido;
        }

        public void setPedido(Double pedido) {
            this.pedido = pedido;
        }

        public Double getDisponible() {
            return disponible;
        }

        public void setDisponible(Double disponible) {
            this.disponible = disponible;
        }

        public Double getStock_minimo() {
            return stock_minimo;
        }

        public void setStock_minimo(Double stock_minimo) {
            this.stock_minimo = stock_minimo;
        }

        public Double getStock_maximo() {
            return stock_maximo;
        }

        public void setStock_maximo(Double stock_maximo) {
            this.stock_maximo = stock_maximo;
        }

        public Double getCosto() {
            return costo;
        }

        public void setCosto(Double costo) {
            this.costo = costo;
        }

        public Boolean getActivo() {
            return activo;
        }

        public void setActivo(Boolean activo) {
            this.activo = activo;
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

        @DatabaseTable(tableName = "inventario_ubicaciones")
        public static class Ubicacion {
            @DatabaseField(columnName = "id", id = true, unique = true)
            @SerializedName("id")
            @Expose
            private Integer id;

            @DatabaseField(columnName = "articulo_id")
            @SerializedName("articulo_id")
            @Expose
            private Integer articulo_id;

            @DatabaseField(columnName = "almacen_id")
            @SerializedName("almacen_id")
            @Expose
            private Integer almacen_id;

            @DatabaseField(columnName = "ubicacion_id")
            @SerializedName("ubicacion_id")
            @Expose
            private Integer ubicacion_id;

            @DatabaseField(columnName = "stock")
            @SerializedName("stock")
            @Expose
            private Double stock;

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
                    return MainActivity.db.InventarioUbicaciones();
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

            public static Ubicacion Obtener(Integer articulo_id, Integer almacen_id, Integer ubicacion_id)
            {
                try
                {
                    return (Ubicacion) Ubicaciones().queryBuilder().where().eq("articulo_id", articulo_id).and().eq("almacen_id", almacen_id).and().eq("ubicacion_id", ubicacion_id).queryForFirst();
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
                    List<Ubicacion> ubicaciones = MainActivity.api.inventario_ubicaciones(id).execute().body();
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
                } catch (Exception ex) {
                    Global.setError(ex);
                }
            }

            public static void SincronizarAsync(int id) {
                MainActivity.api.inventario_ubicaciones(id).enqueue(new Callback<List<Ubicacion>>() {
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

            public Integer getArticulo_id() {
                return articulo_id;
            }

            public void setArticulo_id(Integer articulo_id) {
                this.articulo_id = articulo_id;
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

            public Double getStock() {
                return stock;
            }

            public void setStock(Double stock) {
                this.stock = stock;
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

    public static class ArticuloAPI
    {
        private Articulo articulo;
        private List<Precio> precios;
        private  List<Inventario> inventario;

        public ArticuloAPI() {
            articulo = new Articulo();
            precios = new ArrayList<>();
            inventario = new ArrayList<>();
        }

        public static boolean Busqueda(String q, int lista_precio_id)
        {
            try {
                List<ArticuloAPI> articulos = MainActivity.api.articulos_api_busqueda(Global.getUsuario().getAlmacen_id(), lista_precio_id, q).execute().body();
                for (ArticuloAPI articulo : articulos) {
                    try {
                        if (articulo.articulo.Obtener(articulo.articulo.id) == null) {
                            articulo.articulo.Agregar();
                        } else {
                            articulo.articulo.Actualizar();
                        }

                        for (Precio precio : articulo.precios) {
                            if (precio.Obtener(precio.id) == null) {
                                precio.Agregar();
                            } else {
                                precio.Actualizar();
                            }
                        }

                        if (articulo.articulo.almacenable)
                        {
                            for (Inventario inventario : articulo.inventario) {
                                if (inventario.Obtener(inventario.id) == null) {
                                    inventario.Agregar();
                                } else {
                                    inventario.Actualizar();
                                }
                            }
                        }
                    } catch (Exception ex) {
                        Global.setError(ex);
                        continue;
                    }
                }
                FechaSincronizacion.Obtener("articulos").Actualizar();
                return true;
            } catch (Exception ex) {
                Global.setError(ex);
                return false;
            } finally {
                Global.setSincronizando(false);
            }
        }

        public static boolean Sincronizar(String fecha)
        {
            try {
                List<ArticuloAPI> articulos = MainActivity.api.articulos_api_almacen(Global.getUsuario().getAlmacen_id(), fecha).execute().body();
                for (ArticuloAPI articulo : articulos) {
                    try {
                        if (articulo.articulo.Obtener(articulo.articulo.id) == null) {
                            articulo.articulo.Agregar();
                        } else {
                            articulo.articulo.Actualizar();
                        }

                        for (Precio precio : articulo.precios) {
                            if (precio.Obtener(precio.id) == null) {
                                precio.Agregar();
                            } else {
                                precio.Actualizar();
                            }
                        }

                        if (articulo.articulo.almacenable)
                        {
                            for (Inventario inventario : articulo.inventario) {
                                if (inventario.Obtener(inventario.id) == null) {
                                    inventario.Agregar();
                                } else {
                                    inventario.Actualizar();
                                }
                            }
                        }
                    } catch (Exception ex) {
                        Global.setError(ex);
                        continue;
                    }
                }
                FechaSincronizacion.Obtener("articulos").Actualizar();
                return true;
            } catch (Exception ex) {
                Global.setError(ex);
                return false;
            } finally {
                Global.setSincronizando(false);
            }
        }
    }
}