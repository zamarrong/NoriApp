package mx.nori.nori.documentos.documento;

import android.os.Bundle;
import android.support.v4.app.Fragment;
import android.support.v7.widget.DividerItemDecoration;
import android.support.v7.widget.LinearLayoutManager;
import android.support.v7.widget.RecyclerView;
import android.view.KeyEvent;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.AdapterView;
import android.widget.ArrayAdapter;
import android.widget.AutoCompleteTextView;
import android.widget.Spinner;
import android.widget.Toast;

import mx.nori.nori.NoriSDK.Almacen;
import mx.nori.nori.NoriSDK.Articulo;
import mx.nori.nori.NoriSDK.Global;
import mx.nori.nori.R;

public class DocumentoPartidasIFFragment extends Fragment {

    AutoCompleteTextView editTextArticulo;
    RecyclerView mRecyclerView;
    private RecyclerView.Adapter mAdapter;
    private RecyclerView.LayoutManager mLayoutManager;

    @Override
    public View onCreateView(LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
        // Inflate the layout for this fragment
        final View view = inflater.inflate(R.layout.fragment_documento_partidas, container, false);

        editTextArticulo = view.findViewById(R.id.editTextArticulo);
        mRecyclerView = view.findViewById(R.id.recyclerView);
        mRecyclerView.setHasFixedSize(true);

        mLayoutManager = new LinearLayoutManager(getActivity());
        mRecyclerView.setLayoutManager(mLayoutManager);

        if (editTextArticulo.getAdapter() == null) {
            ArticulosAdapter articulos = new ArticulosAdapter(getContext(), R.id.autoCompleteTextViewCodigoSN, Articulo.Listar());
            editTextArticulo.setAdapter(articulos);
            editTextArticulo.setOnItemClickListener(onItemClickListener);
        }

        editTextArticulo.setOnKeyListener(new View.OnKeyListener() {
            public boolean onKey(View view, int keyCode, KeyEvent keyevent) {
                if ((keyevent.getAction() == KeyEvent.ACTION_DOWN) && (keyCode == KeyEvent.KEYCODE_ENTER)) {
                    try {
                        String q = editTextArticulo.getText().toString();
                        if (!q.isEmpty()) {
                            if (DocumentoActivity.getDocumento().AgregarPartida(q, 0.0)) {
                               Cargar();
                            } else {
                                Toast.makeText(getContext(), Global.getError().getMessage(), Toast.LENGTH_SHORT).show();
                            }
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

        return view;
    }

    private AdapterView.OnItemClickListener onItemClickListener = new AdapterView.OnItemClickListener(){
        @Override
        public void onItemClick(AdapterView<?> adapterView, View view, int i, long l) {
            try {
                if (DocumentoActivity.getDocumento().getId() == 0) {
                    Articulo articulo = (Articulo) adapterView.getItemAtPosition(i);
                    if (DocumentoActivity.getDocumento().AgregarPartida(articulo.getSku(), 0.0)) {
                        Cargar();
                    } else {
                        Toast.makeText(getContext(), Global.getError().getMessage(), Toast.LENGTH_SHORT).show();
                    }
                }
            } catch (Exception ex) {
                return;
            } finally {
                editTextArticulo.setText("");
                editTextArticulo.requestFocus();
            }
        }
    };

    @Override
    public void setUserVisibleHint(boolean isVisibleToUser) {
        super.setUserVisibleHint(isVisibleToUser);
        if (isVisibleToUser) {
            Cargar();
        }
    }

    private void Cargar() {
        try {
            mAdapter = new PartidasIFAdapter(getActivity(), DocumentoActivity.getDocumento().getPartidas());
            mRecyclerView.setAdapter(mAdapter);
            mRecyclerView.addItemDecoration(new DividerItemDecoration(getActivity(), DividerItemDecoration.VERTICAL));

        } catch (Exception ex) {
            //
        }
    }
}
