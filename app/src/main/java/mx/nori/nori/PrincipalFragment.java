package mx.nori.nori;

import android.app.Fragment;
import android.os.Bundle;
import android.view.KeyEvent;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.AdapterView;
import android.widget.ArrayAdapter;
import android.widget.EditText;
import android.widget.Spinner;
import android.widget.TextView;
import android.widget.Toast;

import java.util.List;

import mx.nori.nori.NoriSDK.Almacen;
import mx.nori.nori.NoriSDK.Articulo;
import mx.nori.nori.NoriSDK.Empresa;
import mx.nori.nori.NoriSDK.Global;
import mx.nori.nori.NoriSDK.GrupoArticulo;
import mx.nori.nori.NoriSDK.ListaPrecio;
import mx.nori.nori.NoriSDK.Moneda;
import mx.nori.nori.NoriSDK.Socio;

public class PrincipalFragment extends Fragment {

    EditText editTextArticulo;
    TextView textViewID, textViewGrupoarticulo, textViewSKU, textViewNombre, textViewPrecio, textViewMoneda, textViewStock;
    Spinner spinnerListasPrecios;
    Articulo articulo = new Articulo();

    @Override
    public View onCreateView(LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
        // Inflate the layout for this fragment
        final View view = inflater.inflate(R.layout.fragment_principal, container, false);
        Empresa empresa = Empresa.Obtener();
        String title = (empresa != null) ? empresa.getNombre_comercial() : "Nori";
        ((MainActivity) getActivity()).getSupportActionBar().setTitle(title);

        editTextArticulo = view.findViewById(R.id.editTextArticulo);

        textViewID = view.findViewById(R.id.textViewID);
        textViewGrupoarticulo = view.findViewById(R.id.textViewGrupoArticulo);
        textViewSKU = view.findViewById(R.id.textViewSKU);
        textViewNombre = view.findViewById(R.id.textViewSocio);
        textViewPrecio = view.findViewById(R.id.textViewPrecio);
        textViewMoneda = view.findViewById(R.id.textViewMoneda);
        spinnerListasPrecios = view.findViewById(R.id.spinnerListasPrecios);
        textViewStock = view.findViewById(R.id.textViewStock);

        if (Global.getUsuario() != null) {
            List<ListaPrecio> listas_precios = Global.getUsuario().ListasPrecios();
            if (listas_precios != null) {
                ArrayAdapter<ListaPrecio> adapter = new ArrayAdapter<>(getActivity(), android.R.layout.simple_spinner_dropdown_item, listas_precios);
                adapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item);

                spinnerListasPrecios.setAdapter(adapter);
            }
        }

        editTextArticulo.setOnKeyListener(new View.OnKeyListener() {
            public boolean onKey(View view, int keyCode, KeyEvent keyevent) {
                //If the keyevent is a key-down event on the "enter" button
                if ((keyevent.getAction() == KeyEvent.ACTION_DOWN) && (keyCode == KeyEvent.KEYCODE_ENTER)) {
                    try {
                        if (!editTextArticulo.getText().toString().isEmpty()) {
                            articulo = Articulo.Obtener(editTextArticulo.getText().toString());
                            Cargar();
                            if (articulo == null) {
                                editTextArticulo.setText("");
                                Toast.makeText(getActivity(), "Artículo no encontrado", Toast.LENGTH_SHORT).show();
                            }
                        } else {
                            Toast.makeText(getActivity(), "Ingrese el código del artículo", Toast.LENGTH_SHORT).show();
                        }
                        return true;
                    } catch (Exception ex) {
                        return false;
                    } finally {
                        editTextArticulo.setText("");
                        editTextArticulo.requestFocus();
                    }
                }
                return false;
            }
        });

        spinnerListasPrecios.setOnItemSelectedListener(new AdapterView.OnItemSelectedListener() {
            public void onItemSelected(AdapterView<?> parent, View view, int position, long id)
            {
                try {
                    if (spinnerListasPrecios.isEnabled()) {
                        CargarPrecio();
                    }
                } catch (Exception ex) {
                    //
                }
            }
            public void onNothingSelected(AdapterView<?> parent)
            {
                //
            }
        });

        return view;
    }

    private Boolean Cargar()
    {
        try {
            if (articulo != null) {
                textViewID.setText(articulo.getId().toString());

                GrupoArticulo grupo_articulo = GrupoArticulo.Obtener(articulo.getGrupo_articulo_id());
                if (grupo_articulo != null) {
                    textViewGrupoarticulo.setText(grupo_articulo.getNombre());
                } else {
                    textViewGrupoarticulo.setText("");
                }

                textViewSKU.setText(articulo.getSku());
                textViewNombre.setText(articulo.getNombre());

                /*Socio socio = Socio.Obtener(Global.getUsuario().getSocio_id());
                if (socio != null) {
                    Articulo.Precio precio = Articulo.Precio.Obtener(articulo.getGrupo_articulo_id(), socio.getLista_precio_id());
                    if (precio != null) {
                        textViewPrecio.setText(Functions.toCurrency(precio.getPrecio()));
                        Moneda moneda = Moneda.Obtener(precio.getMoneda_id());
                        if (moneda != null) {
                            textViewMoneda.setText(moneda.getNombre());
                        }
                    } else {
                        textViewPrecio.setText(Functions.toCurrency(0.00));
                    }
                }*/

                int almacen_id = Global.getUsuario().getAlmacen_id();
                if (almacen_id == 0)
                {
                    almacen_id = articulo.getAlmacen_id();
                }
                Almacen almacen = Almacen.Obtener(almacen_id);
                if (almacen  != null) {
                    if (almacen.getUbicaciones()) {
                        Articulo.Inventario.Ubicacion inventario = Articulo.Inventario.Ubicacion.Obtener(articulo.getId(), almacen.getId(), Global.getUsuario().getUbicacion_id());
                        Almacen.Ubicacion ubicacion = Almacen.Ubicacion.Obtener(inventario.getUbicacion_id());
                        if (inventario != null && ubicacion != null) {
                            textViewStock.setText(String.format("%s (%s - %s)", inventario.getStock().toString(), almacen.getNombre(), ubicacion.getUbicacion()));
                        } else {
                            textViewStock.setText("0");
                        }
                    } else {
                        Articulo.Inventario inventario = Articulo.Inventario.Obtener(articulo.getId(), almacen.getId());
                        if (inventario != null) {
                            textViewStock.setText(String.format("%s (%s)", inventario.getStock().toString(), almacen.getNombre()));
                        } else {
                            textViewStock.setText("0");
                        }
                    }
                }

                editTextArticulo.setText("");
                CargarPrecio();
                return true;
            } else {
                textViewID.setText("");
                textViewGrupoarticulo.setText("");
                textViewSKU.setText("");
                textViewNombre.setText("");
                textViewPrecio.setText("");
                textViewStock.setText("");
                return false;
            }
        } catch (Exception ex) {
            return false;
        }
    }

    private void CargarPrecio() {
        try {
            if (articulo.getId() != 0) {
                Articulo.Precio precio = Articulo.Precio.Obtener(articulo.getId(), ((ListaPrecio) spinnerListasPrecios.getSelectedItem()).getId(), articulo.getUnidad_medida_id());
                if (precio != null) {
                    textViewPrecio.setText(Functions.toCurrency(precio.getPrecio()));
                    Moneda moneda = Moneda.Obtener(precio.getMoneda_id());
                    if (moneda != null) {
                        textViewMoneda.setText(moneda.getNombre());
                    }
                } else {
                    textViewPrecio.setText(Functions.toCurrency(0.00));
                }
            }
        } catch (Exception ex) {
            //
        }
    }
}
