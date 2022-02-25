package mx.nori.nori.socios;

import android.app.Fragment;
import android.os.Bundle;
import android.support.v7.widget.DividerItemDecoration;
import android.support.v7.widget.LinearLayoutManager;
import android.support.v7.widget.RecyclerView;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Toast;

import java.util.Collections;
import java.util.Comparator;
import java.util.List;

import mx.nori.nori.MainActivity;
import mx.nori.nori.NoriSDK.Socio;
import mx.nori.nori.R;

public class SociosFragment extends Fragment {

    RecyclerView mRecyclerView;
    private RecyclerView.Adapter mAdapter;
    private RecyclerView.LayoutManager mLayoutManager;

    @Override
    public View onCreateView(LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
        // Inflate the layout for this fragment
        final View view = inflater.inflate(R.layout.fragment_socios, container, false);
        ((MainActivity) getActivity()).getSupportActionBar().setTitle("Socios");

        mRecyclerView = view.findViewById(R.id.recyclerView);
        mRecyclerView.setHasFixedSize(true);

        mLayoutManager = new LinearLayoutManager(getActivity());
        mRecyclerView.setLayoutManager(mLayoutManager);

        List<Socio> socios = Socio.Listar();

        Collections.sort(socios, new Comparator<Socio>() {
            @Override
            public int compare(Socio o1, Socio o2) {
                return o1.getNombre().compareToIgnoreCase(o2.getNombre());
            }
        });

        mAdapter = new SociosAdapter(getActivity(), socios);
        mRecyclerView.setAdapter(mAdapter);
        mRecyclerView.addItemDecoration(new DividerItemDecoration(getActivity(), DividerItemDecoration.VERTICAL));

        Toast.makeText(getActivity(), String.format("Socios (%s)", socios.size()), Toast.LENGTH_LONG).show();

        return view;
    }
}