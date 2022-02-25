package mx.nori.nori.documentos;

import android.app.Fragment;
import android.content.Intent;
import android.os.Bundle;
import android.os.Handler;
import android.support.v4.widget.SwipeRefreshLayout;
import android.support.v7.widget.DividerItemDecoration;
import android.support.v7.widget.LinearLayoutManager;
import android.support.v7.widget.RecyclerView;
import android.view.LayoutInflater;
import android.view.Menu;
import android.view.MenuInflater;
import android.view.MenuItem;
import android.view.View;
import android.view.ViewGroup;

import mx.nori.nori.MainActivity;
import mx.nori.nori.R;
import mx.nori.nori.NoriSDK.Documento;
import mx.nori.nori.documentos.documento.DocumentoActivity;

public class DocumentosFragment extends Fragment implements SwipeRefreshLayout.OnRefreshListener {

    SwipeRefreshLayout swipeRefreshLayout;
    RecyclerView mRecyclerView;
    private RecyclerView.Adapter mAdapter;
    private RecyclerView.LayoutManager mLayoutManager;

    private String clase;

    @Override
    public View onCreateView(LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
        // Inflate the layout for this fragment
        setHasOptionsMenu(true);
        final View view = inflater.inflate(R.layout.fragment_documentos, container, false);
        clase = getArguments().getString("clase");

        String title;

        switch (clase) {
            case "CO":
                title = "Cotizaciones";
                break;
            case "PE":
                title = "Pedidos";
                break;
            case "EN":
                title = "Entregas";
                break;
            case "DV":
                title = "Devoluciones";
                break;
            case "FA":
                title = "Facturas";
                break;
            case "NC":
                title = "Notas de crédito";
                break;
            case "ST":
                title = "Solicitudes de traslado";
                break;
            case "TS":
                title = "Transferencias de stock";
                break;
            case "IF":
                title = "Inventarios físicos";
                break;
            default:
                title = "Documentos";
                break;
        }

        ((MainActivity) getActivity()).getSupportActionBar().setTitle(title);

        swipeRefreshLayout = view.findViewById(R.id.swipeRefreshLayout);
        swipeRefreshLayout.setOnRefreshListener(this);
        mRecyclerView = view.findViewById(R.id.recyclerView);
        mRecyclerView.setHasFixedSize(true);

        mLayoutManager = new LinearLayoutManager(getActivity());
        mRecyclerView.setLayoutManager(mLayoutManager);

        Cargar();
        return view;
    }

    @Override
    public void onCreateOptionsMenu(Menu menu, MenuInflater inflater) {
        menu.clear();
        inflater.inflate(R.menu.documentos, menu);
        super.onCreateOptionsMenu(menu, inflater);
    }

    @Override
    public boolean onOptionsItemSelected(MenuItem item) {
        switch (item.getItemId()) {
            case R.id.nuevo:
                Intent intent = new Intent(getActivity(), DocumentoActivity.class);
                intent.putExtra("clase", clase);
                startActivity(intent);
                return true;
            case R.id.actualizar:
                Cargar();
                return true;
        }
        return super.onOptionsItemSelected(item);
    }

    @Override
    public void onRefresh() {
        new Handler().postDelayed(new Runnable() {
            @Override public void run() {
                Cargar();
                swipeRefreshLayout.setRefreshing(false);
            }
        }, 5000);
    }


    private void Cargar()
    {
        try
        {
            mAdapter = new DocumentosAdapter(getActivity(), Documento.ListarPorClase(clase));
            mRecyclerView.setAdapter(mAdapter);
            mRecyclerView.addItemDecoration(new DividerItemDecoration(getActivity(), DividerItemDecoration.VERTICAL));
        } catch (Exception ex) {
            //
        }
    }
}