package mx.nori.nori.NoriSDK;

import java.sql.SQLException;

import android.content.Context;
import android.database.sqlite.SQLiteDatabase;

import com.j256.ormlite.android.apptools.OrmLiteSqliteOpenHelper;
import com.j256.ormlite.dao.Dao;
import com.j256.ormlite.support.ConnectionSource;
import com.j256.ormlite.table.TableUtils;

public class DB extends OrmLiteSqliteOpenHelper {

    private static final String DATABASE_NAME = "nori.db";
    private static final int DATABASE_VERSION = 1;

    //General
    private Dao<Configuracion, Integer> configuracion;
    private Dao<Empresa, Integer> empresa;
    private Dao<Usuario, Integer> usuarios;
    private Dao<Usuario.ListaPrecio, Integer> usuarios_listas_precios;
    private Dao<Almacen, Integer> almacenes;
    private Dao<Almacen.Ubicacion, Integer> almacenes_ubicaciones;
    private Dao<Moneda, Integer> monedas;
    private Dao<TipoCambio, Integer> tipos_cambio;
    private Dao<Impuesto, Integer> impuestos;
    private Dao<ListaPrecio, Integer> listas_precios;
    private Dao<MetodoPago, Integer> metodos_pago;
    private Dao<MetodoPago.Tipo, Integer> tipos_metodos_pago;
    private Dao<CondicionesPago, Integer> condiciones_pago;
    private Dao<Fabricante, Integer> fabricantes;
    private Dao<GrupoSocio, Integer> grupos_socios;
    private Dao<GrupoArticulo, Integer> grupos_articulos;
    private Dao<UnidadMedida, Integer> unidades_medida;
    private Dao<Pais, Integer> paises;
    private Dao<Estado, Integer> estados;
    private Dao<Vendedor, Integer> vendedores;
    private Dao<Serie, Integer> series;
    private Dao<FechaSincronizacion, Integer> fechas_sincronizacion;
    private Dao<Actividad, Integer> actividades;
    private Dao<Actividad.Tipo, Integer> tipos_actividades;
    private Dao<Causalidad, Integer> causalidades;
    private Dao<Ruta, Integer> rutas;
    //Socios
    private Dao<Socio, Integer> socios;
    private Dao<Socio.Direccion, Integer> direcciones;
    //Articulos
    private Dao<Articulo, Integer> articulos;
    private Dao<Articulo.Precio, Integer> precios;
    private Dao<Articulo.CodigoBarras, Integer> codigos_barras;
    private Dao<Articulo.Inventario, Integer> inventario;
    private Dao<Articulo.Inventario.Ubicacion, Integer> inventario_ubicaciones;
    //Documentos
    private Dao<Documento, Integer> documentos;
    private Dao<Documento.Partida, Integer> partidas;
    //Flujo
    private Dao<Flujo, Integer> flujo;

    public DB(Context context) {
        super(context, DATABASE_NAME, null, DATABASE_VERSION);
    }

    @Override
    public void onCreate(SQLiteDatabase db, ConnectionSource connectionSource) {
        try {
            //General
            TableUtils.createTable(connectionSource, Configuracion.class);
            TableUtils.createTable(connectionSource, Empresa.class);
            TableUtils.createTable(connectionSource, Usuario.class);
            TableUtils.createTable(connectionSource, Usuario.ListaPrecio.class);
            TableUtils.createTable(connectionSource, Almacen.class);
            TableUtils.createTable(connectionSource, Almacen.Ubicacion.class);
            TableUtils.createTable(connectionSource, Moneda.class);
            TableUtils.createTable(connectionSource, TipoCambio.class);
            TableUtils.createTable(connectionSource, Impuesto.class);
            TableUtils.createTable(connectionSource, ListaPrecio.class);
            TableUtils.createTable(connectionSource, MetodoPago.class);
            TableUtils.createTable(connectionSource, MetodoPago.Tipo.class);
            TableUtils.createTable(connectionSource, CondicionesPago.class);
            TableUtils.createTable(connectionSource, Fabricante.class);
            TableUtils.createTable(connectionSource, GrupoSocio.class);
            TableUtils.createTable(connectionSource, GrupoArticulo.class);
            TableUtils.createTable(connectionSource, UnidadMedida.class);
            TableUtils.createTable(connectionSource, Pais.class);
            TableUtils.createTable(connectionSource, Estado.class);
            TableUtils.createTable(connectionSource, Vendedor.class);
            TableUtils.createTable(connectionSource, Serie.class);
            TableUtils.createTable(connectionSource, FechaSincronizacion.class);
            TableUtils.createTable(connectionSource, Actividad.class);
            TableUtils.createTable(connectionSource, Actividad.Tipo.class);
            TableUtils.createTable(connectionSource, Causalidad.class);
            TableUtils.createTable(connectionSource, Ruta.class);
            //Socios
            TableUtils.createTable(connectionSource, Socio.class);
            TableUtils.createTable(connectionSource, Socio.Direccion.class);
            //Articulos
            TableUtils.createTable(connectionSource, Articulo.class);
            TableUtils.createTable(connectionSource, Articulo.Precio.class);
            TableUtils.createTable(connectionSource, Articulo.CodigoBarras.class);
            TableUtils.createTable(connectionSource, Articulo.Inventario.class);
            TableUtils.createTable(connectionSource, Articulo.Inventario.Ubicacion.class);
            //Documentos
            TableUtils.createTable(connectionSource, Documento.class);
            TableUtils.createTable(connectionSource, Documento.Partida.class);
            //Flujo
            TableUtils.createTable(connectionSource, Flujo.class);
        } catch (SQLException e) {
            throw new RuntimeException(e);
        }
    }

    @Override
    public void onUpgrade(SQLiteDatabase db, ConnectionSource connectionSource, int oldVersion, int newVersion) {
        onCreate(db, connectionSource);
    }

    //General
    public Dao<Configuracion, Integer> Configuracion() throws SQLException {
        if (configuracion == null) {
            configuracion = getDao(Configuracion.class);
        }
        return configuracion;
    }

    public Dao<Empresa, Integer> Empresa() throws SQLException {
        if (empresa == null) {
            empresa = getDao(Empresa.class);
        }
        return empresa;
    }

    public Dao<Usuario, Integer> Usuarios() throws SQLException {
        if (usuarios == null) {
            usuarios = getDao(Usuario.class);
        }
        return usuarios;
    }

    public Dao<Usuario.ListaPrecio, Integer> UsuariosListasPrecios() throws SQLException {
        if (usuarios_listas_precios == null) {
             usuarios_listas_precios = getDao(Usuario.ListaPrecio.class);
        }
        return usuarios_listas_precios;
    }

    public Dao<Almacen, Integer> Almacenes() throws SQLException {
        if (almacenes == null) {
            almacenes = getDao(Almacen.class);
        }
        return almacenes;
    }

    public Dao<Almacen.Ubicacion, Integer> AlmacenesUbicaciones() throws SQLException {
        if (almacenes_ubicaciones == null) {
            almacenes_ubicaciones = getDao(Almacen.Ubicacion.class);
        }
        return almacenes_ubicaciones;
    }

    public Dao<Moneda, Integer> Monedas() throws SQLException {
        if (monedas == null) {
            monedas = getDao(Moneda.class);
        }
        return monedas;
    }

    public Dao<TipoCambio, Integer> TiposCambio() throws SQLException {
        if (tipos_cambio == null) {
            tipos_cambio = getDao(TipoCambio.class);
        }
        return tipos_cambio;
    }

    public Dao<Impuesto, Integer> Impuestos() throws SQLException {
        if (impuestos == null) {
            impuestos = getDao(Impuesto.class);
        }
        return impuestos;
    }

    public Dao<ListaPrecio, Integer> ListasPrecios() throws SQLException {
        if (listas_precios == null) {
            listas_precios = getDao(ListaPrecio.class);
        }
        return listas_precios;
    }

    public Dao<MetodoPago, Integer> MetodosPago() throws SQLException {
        if (metodos_pago == null) {
            metodos_pago = getDao(MetodoPago.class);
        }
        return metodos_pago;
    }

    public Dao<MetodoPago.Tipo, Integer> TiposMetodosPago() throws SQLException {
        if (tipos_metodos_pago == null) {
            tipos_metodos_pago = getDao(MetodoPago.Tipo.class);
        }
        return tipos_metodos_pago;
    }

    public Dao<CondicionesPago, Integer> CondicionesPago() throws SQLException {
        if (condiciones_pago == null) {
            condiciones_pago = getDao(CondicionesPago.class);
        }
        return condiciones_pago;
    }

    public Dao<Fabricante, Integer> Fabricantes() throws SQLException {
        if (fabricantes == null) {
            fabricantes = getDao(Fabricante.class);
        }
        return fabricantes;
    }

    public Dao<GrupoSocio, Integer> GruposSocios() throws SQLException {
        if (grupos_socios == null) {
            grupos_socios = getDao(GrupoSocio.class);
        }
        return grupos_socios;
    }

    public Dao<GrupoArticulo, Integer> GruposArticulos() throws SQLException {
        if (grupos_articulos == null) {
            grupos_articulos = getDao(GrupoArticulo.class);
        }
        return grupos_articulos;
    }

    public Dao<UnidadMedida, Integer> UnidadesMedida() throws SQLException {
        if (unidades_medida == null) {
            unidades_medida = getDao(UnidadMedida.class);
        }
        return unidades_medida;
    }

    public Dao<Pais, Integer> Paises() throws SQLException {
        if (paises == null) {
            paises = getDao(Pais.class);
        }
        return paises;
    }

    public Dao<Estado, Integer> Estados() throws SQLException {
        if (estados == null) {
            estados = getDao(Estado.class);
        }
        return estados;
    }

    public Dao<Vendedor, Integer> Vendedores() throws SQLException {
        if (vendedores == null) {
            vendedores = getDao(Vendedor.class);
        }
        return vendedores;
    }

    public Dao<Serie, Integer> Series() throws SQLException {
        if (series == null) {
            series = getDao(Serie.class);
        }
        return series;
    }

    public Dao<FechaSincronizacion, Integer> FechasSincronizacion() throws SQLException {
        if (fechas_sincronizacion == null) {
            fechas_sincronizacion = getDao(FechaSincronizacion.class);
        }
        return fechas_sincronizacion;
    }

    public Dao<Actividad, Integer> Actividades() throws SQLException {
        if (actividades == null) {
            actividades = getDao(Actividad.class);
        }
        return actividades;
    }

    public Dao<Actividad.Tipo, Integer> TiposActividades() throws SQLException {
        if (tipos_actividades == null) {
            tipos_actividades = getDao(Actividad.Tipo.class);
        }
        return tipos_actividades;
    }

    public Dao<Causalidad, Integer> Causalidades() throws SQLException {
        if (causalidades == null) {
            causalidades = getDao(Causalidad.class);
        }
        return causalidades;
    }

    public Dao<Ruta, Integer> Rutas() throws SQLException {
        if (rutas == null) {
            rutas = getDao(Ruta.class);
        }
        return rutas;
    }

    //Socios
    public Dao<Socio, Integer> Socios() throws SQLException {
        if (socios == null) {
            socios = getDao(Socio.class);
        }
        return socios;
    }

    public Dao<Socio.Direccion, Integer> Direcciones() throws SQLException {
        if (direcciones == null) {
            direcciones = getDao(Socio.Direccion.class);
        }
        return direcciones;
    }

    //Articulos
    public Dao<Articulo, Integer> Articulos() throws SQLException {
        if (articulos == null) {
            articulos = getDao(Articulo.class);
        }
        return articulos;
    }

    public Dao<Articulo.Precio, Integer> Precios() throws SQLException {
        if (precios == null) {
            precios = getDao(Articulo.Precio.class);
        }
        return precios;
    }

    public Dao<Articulo.CodigoBarras, Integer> CodigosBarras() throws SQLException {
        if (codigos_barras == null) {
            codigos_barras = getDao(Articulo.CodigoBarras.class);
        }
        return codigos_barras;
    }

    public Dao<Articulo.Inventario, Integer> Inventarios() throws SQLException {
        if (inventario == null) {
            inventario = getDao(Articulo.Inventario.class);
        }
        return inventario;
    }

    public Dao<Articulo.Inventario.Ubicacion, Integer> InventarioUbicaciones() throws SQLException {
        if (inventario_ubicaciones == null) {
            inventario_ubicaciones = getDao(Articulo.Inventario.Ubicacion.class);
        }
        return inventario_ubicaciones;
    }

    //Documentos
    public Dao<Documento, Integer> Documentos() throws SQLException {
        if (documentos == null) {
            documentos = getDao(Documento.class);
        }
        return documentos;
    }

    public Dao<Documento.Partida, Integer> Partidas() throws SQLException {
        if (partidas == null) {
            partidas = getDao(Documento.Partida.class);
        }
        return partidas;
    }

    //Flujo
    public Dao<Flujo, Integer> Flujo() throws SQLException {
        if (flujo == null) {
            flujo = getDao(Flujo.class);
        }
        return flujo;
    }

    @Override
    public void close() {
        super.close();
    }
}
