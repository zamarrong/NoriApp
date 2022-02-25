package mx.nori.nori.articulos.articulo;

import android.os.Bundle;
import android.support.v4.app.Fragment;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.TextView;

import mx.nori.nori.Functions;
import mx.nori.nori.NoriSDK.Moneda;
import mx.nori.nori.R;
import mx.nori.nori.NoriSDK.Almacen;
import mx.nori.nori.NoriSDK.Articulo;
import mx.nori.nori.NoriSDK.Global;
import mx.nori.nori.NoriSDK.GrupoArticulo;

public class ArticuloGeneralFragment extends Fragment {

    TextView textViewID, textViewGrupoArticulo, textViewSKU, textViewNombre, textViewPrecio, textViewMoneda, textViewCodigoBarras, textViewStock;

    @Override
    public View onCreateView(LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
        // Inflate the layout for this fragment
        final View view = inflater.inflate(R.layout.fragment_articulo_general, container, false);

        textViewID = view.findViewById(R.id.textViewID);
        textViewGrupoArticulo = view.findViewById(R.id.textViewGrupoArticulo);
        textViewSKU = view.findViewById(R.id.textViewSKU);
        textViewNombre = view.findViewById(R.id.textViewSocio);
        textViewPrecio = view.findViewById(R.id.textViewPrecio);
        textViewMoneda = view.findViewById(R.id.textViewMoneda);
        textViewCodigoBarras = view.findViewById(R.id.textViewCodigoBarras);
        textViewStock = view.findViewById(R.id.textViewStock);

        Cargar();

        return view;
    }

    private Boolean Cargar()
    {
        try {
            if (ArticuloActivity.getArticulo() != null) {
                textViewID.setText(ArticuloActivity.getArticulo().getId().toString());

                GrupoArticulo grupo_articulo = GrupoArticulo.Obtener(ArticuloActivity.getArticulo().getGrupo_articulo_id());
                if (grupo_articulo != null) {
                    textViewGrupoArticulo.setText(grupo_articulo.getNombre());
                } else {
                    textViewGrupoArticulo.setText("");
                }

                textViewSKU.setText(ArticuloActivity.getArticulo().getSku());
                textViewNombre.setText(ArticuloActivity.getArticulo().getNombre());

                Articulo.Precio precio = Articulo.Precio.Obtener(ArticuloActivity.getArticulo().getId(), Global.getConfiguracion().getLista_precio_id(), ArticuloActivity.getArticulo().getUnidad_medida_id());
                if (precio != null) {
                    textViewPrecio.setText(Functions.toCurrency(precio.getPrecio()));
                    Moneda moneda = Moneda.Obtener(precio.getMoneda_id());
                    if (moneda != null) {
                        textViewMoneda.setText(moneda.getNombre());
                    }
                } else {
                    textViewPrecio.setText(Functions.toCurrency(0.00));
                }
                int almacen_id = Global.getUsuario().getAlmacen_id();
                if (almacen_id == 0)
                {
                    almacen_id = ArticuloActivity.getArticulo().getAlmacen_id();
                }
                Articulo.Inventario inventario = Articulo.Inventario.Obtener(ArticuloActivity.getArticulo().getId(), almacen_id);
                if (inventario != null) {
                    Almacen almacen = Almacen.Obtener(inventario.getAlmacen_id());
                    textViewStock.setText(String.format("%s (%s)", inventario.getStock().toString(), almacen.getNombre()));
                } else {
                    textViewStock.setText("0");
                }

                return true;
            }

            return  false;
        } catch (Exception ex) {
            return false;
        }
    }
}
