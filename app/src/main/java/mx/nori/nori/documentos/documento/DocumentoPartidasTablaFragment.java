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
import android.widget.AutoCompleteTextView;
import android.widget.Toast;

import mx.nori.nori.NoriSDK.Articulo;
import mx.nori.nori.NoriSDK.Documento;
import mx.nori.nori.NoriSDK.Global;
import mx.nori.nori.R;

public class DocumentoPartidasTablaFragment extends Fragment {

    RecyclerView mRecyclerView;

    @Override
    public View onCreateView(LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
        // Inflate the layout for this fragment
        final View view = inflater.inflate(R.layout.fragment_documento_partidas_tabla, container, false);

        mRecyclerView = view.findViewById(R.id.recyclerView);
        mRecyclerView.setHasFixedSize(true);

        RecyclerView.LayoutManager mLayoutManager = new LinearLayoutManager(getActivity());
        mRecyclerView.setLayoutManager(mLayoutManager);
        mRecyclerView.addItemDecoration(new DividerItemDecoration(getActivity(), DividerItemDecoration.VERTICAL));

        return view;
    }

    @Override
    public void setUserVisibleHint(boolean isVisibleToUser) {
        super.setUserVisibleHint(isVisibleToUser);
        if (isVisibleToUser) {
            Cargar();
        }
    }

    private void Cargar() {
        try {
            if (DocumentoActivity.getDocumento().getPartidas().size() == 0) {
                DocumentoActivity.getDocumento().AgregarPartidas();
            }
            RecyclerView.Adapter mAdapter = new PartidasTablaAdapter(getActivity(), DocumentoActivity.getDocumento().getPartidas());
            mRecyclerView.setAdapter(mAdapter);
        } catch (Exception ex) {
            //
        }
    }
}
