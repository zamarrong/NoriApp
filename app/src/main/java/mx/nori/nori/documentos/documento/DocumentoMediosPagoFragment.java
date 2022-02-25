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
import android.widget.ArrayAdapter;
import android.widget.EditText;
import android.widget.Spinner;
import android.widget.TextView;
import android.widget.Toast;

import java.util.List;

import mx.nori.nori.Functions;
import mx.nori.nori.NoriSDK.Flujo;
import mx.nori.nori.NoriSDK.MetodoPago;
import mx.nori.nori.R;

public class DocumentoMediosPagoFragment extends Fragment {

    Spinner spinnerMetodosPago;
    EditText editTextReferencia, editTextImporte;
    TextView textViewTotal, textViewImporteAplicado, textViewDiferencia;
    RecyclerView mRecyclerView;
    private RecyclerView.Adapter mAdapter;
    private RecyclerView.LayoutManager mLayoutManager;

    @Override
    public View onCreateView(LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
        // Inflate the layout for this fragment
        final View view = inflater.inflate(R.layout.fragment_documento_medios_pago, container, false);

        spinnerMetodosPago = view.findViewById(R.id.spinnerMetodosPago);
        editTextReferencia = view.findViewById(R.id.editTextReferencia);
        editTextImporte = view.findViewById(R.id.editTextImporte);
        textViewTotal = view.findViewById(R.id.textViewTipoActividad);
        textViewImporteAplicado = view.findViewById(R.id.textViewImporteAplicado);
        textViewDiferencia = view.findViewById(R.id.textViewDiferencia);
        mRecyclerView = view.findViewById(R.id.recyclerView);
        mRecyclerView.setHasFixedSize(true);

        mLayoutManager = new LinearLayoutManager(getActivity());
        mRecyclerView.setLayoutManager(mLayoutManager);

        List<MetodoPago.Tipo> tipos_metodos_pago = MetodoPago.Tipo.Listar();
        if (tipos_metodos_pago != null) {
            ArrayAdapter<MetodoPago.Tipo> adapter = new ArrayAdapter<>(getContext(),  android.R.layout.simple_spinner_dropdown_item, tipos_metodos_pago);
            adapter.setDropDownViewResource( android.R.layout.simple_spinner_dropdown_item);

            spinnerMetodosPago.setAdapter(adapter);
        }

        mAdapter = new FlujoAdapter(getActivity(), DocumentoActivity.getDocumento().getFlujo());
        mRecyclerView.setAdapter(mAdapter);
        mRecyclerView.addItemDecoration(new DividerItemDecoration(getActivity(), DividerItemDecoration.VERTICAL));

        editTextImporte.setOnKeyListener(new View.OnKeyListener() {
            public boolean onKey(View view, int keyCode, KeyEvent keyevent) {
                if ((keyevent.getAction() == KeyEvent.ACTION_DOWN) && (keyCode == KeyEvent.KEYCODE_ENTER)) {
                    try {
                        Double q = (editTextImporte.getText().toString().length() == 0) ? DocumentoActivity.getDocumento().getTotal() : Double.parseDouble(editTextImporte.getText().toString());
                        Flujo flujo = new Flujo();

                        flujo.setTipo_metodo_pago_id(((MetodoPago.Tipo)spinnerMetodosPago.getSelectedItem()).getId());
                        flujo.setImporte(q);
                        flujo.setReferencia(editTextReferencia.getText().toString());

                        if (flujo.getImporte() <= 0) {
                            Toast.makeText(getContext(), "No es posible agregar un pago con importe <= 0.", Toast.LENGTH_SHORT).show();
                            return  false;
                        }

                        if (flujo.getTipo_metodo_pago_id() == 0) {
                            Toast.makeText(getContext(), "No es posible agregar un pago sin método de pago.", Toast.LENGTH_SHORT).show();
                            return  false;
                        }

                        if ((flujo.getTipo_cambio() * flujo.getImporte()) > (DocumentoActivity.getDocumento().getTotal() - DocumentoActivity.getDocumento().getImporte_aplicado())) {
                            Toast.makeText(getContext(), "No es posible agregar un importe mayor que el saldo restante del documento.", Toast.LENGTH_SHORT).show();
                            return  false;
                        }

                        DocumentoActivity.getDocumento().getFlujo().add(flujo);
                        return true;
                    } catch (Exception ex) {
                        return false;
                    } finally {
                        mAdapter = new FlujoAdapter(getActivity(), DocumentoActivity.getDocumento().getFlujo());
                        mRecyclerView.setAdapter(mAdapter);
                        mRecyclerView.addItemDecoration(new DividerItemDecoration(getActivity(), DividerItemDecoration.VERTICAL));

                        Calcular();

                        editTextReferencia.setText("");
                        editTextImporte.setText("");
                        editTextImporte.requestFocus();
                    }
                }
                return false;
            }
        });
        return view;
    }

    @Override
    public void setUserVisibleHint(boolean isVisibleToUser) {
        super.setUserVisibleHint(isVisibleToUser);
        if (isVisibleToUser) {
            Calcular();
        }
    }

    private void Calcular() {
        try {
            DocumentoActivity.getDocumento().CalcularTotal();
            textViewTotal.setText(Functions.toCurrency(DocumentoActivity.getDocumento().getTotal()));
            textViewImporteAplicado.setText(Functions.toCurrency(DocumentoActivity.getDocumento().getImporte_aplicado()));
            textViewDiferencia.setText(Functions.toCurrency(DocumentoActivity.getDocumento().getTotal() - DocumentoActivity.getDocumento().getImporte_aplicado()));
        } catch (Exception ex) {
            //
        }
    }
}