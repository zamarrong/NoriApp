package mx.nori.nori.documentos.documento;

import android.os.Bundle;
import android.support.v4.app.Fragment;
import android.text.Editable;
import android.text.TextWatcher;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.AdapterView;
import android.widget.ArrayAdapter;
import android.widget.AutoCompleteTextView;
import android.widget.EditText;
import android.widget.Spinner;
import android.widget.TextView;
import android.widget.Toast;

import java.util.List;

import mx.nori.nori.Functions;
import mx.nori.nori.NoriSDK.Documento;
import mx.nori.nori.NoriSDK.Global;
import mx.nori.nori.NoriSDK.ListaPrecio;
import mx.nori.nori.NoriSDK.Moneda;
import mx.nori.nori.NoriSDK.Serie;
import mx.nori.nori.NoriSDK.Socio;
import mx.nori.nori.NoriSDK.Vendedor;
import mx.nori.nori.R;

public class DocumentoGeneralFragment extends Fragment {

    TextView textViewSerie, textViewID, textViewFechaDocumento, textViewSocio, textViewMoneda, textViewVendedor;
    AutoCompleteTextView autoCompleteTextViewCodigoSN;
    Spinner spinnerListasPrecios;
    EditText editTextComentario;

    @Override
    public View onCreateView(LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
        // Inflate the layout for this fragment
        final View view = inflater.inflate(R.layout.fragment_documento_general, container, false);

        textViewSerie = view.findViewById(R.id.textViewSerie);
        textViewID = view.findViewById(R.id.textViewID);
        textViewFechaDocumento = view.findViewById(R.id.textViewFechaDocumento);
        textViewSocio = view.findViewById(R.id.textViewSocio);
        textViewMoneda = view.findViewById(R.id.textViewMoneda);
        textViewVendedor = view.findViewById(R.id.textViewVendedor);
        autoCompleteTextViewCodigoSN = view.findViewById(R.id.autoCompleteTextViewCodigoSN);
        spinnerListasPrecios = view.findViewById(R.id.spinnerListasPrecios);
        editTextComentario = view.findViewById(R.id.editTextComentario);

        if (autoCompleteTextViewCodigoSN.getAdapter() == null) {
            SociosAdapter socios = new SociosAdapter(getContext(), R.id.autoCompleteTextViewCodigoSN, Socio.Listar());
            autoCompleteTextViewCodigoSN.setAdapter(socios);
            autoCompleteTextViewCodigoSN.setOnItemClickListener(onItemClickListener);
        }

        if (Global.getUsuario() != null) {
            List<ListaPrecio> listas_precios = Global.getUsuario().ListasPrecios();
            if (listas_precios != null) {
                ArrayAdapter<ListaPrecio> adapter = new ArrayAdapter<>(getContext(), android.R.layout.simple_spinner_dropdown_item, listas_precios);
                adapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item);

                spinnerListasPrecios.setAdapter(adapter);
            }
        }

        spinnerListasPrecios.setOnItemSelectedListener(new AdapterView.OnItemSelectedListener() {
            public void onItemSelected(AdapterView<?> parent, View view, int position, long id)
            {
                try {
                    if (spinnerListasPrecios.isEnabled()) {
                        if (!DocumentoActivity.getDocumento().getLista_precio_id().equals(((ListaPrecio) spinnerListasPrecios.getSelectedItem()).getId()) && DocumentoActivity.getDocumento().getId() == 0) {
                            DocumentoActivity.getDocumento().setLista_precio_id(((ListaPrecio) spinnerListasPrecios.getSelectedItem()).getId());
                            DocumentoActivity.getDocumento().RecalcularTotalPartidas(true);
                        }
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

        editTextComentario.addTextChangedListener(new editTextWatcher());

        Cargar();

        return view;
    }

    private AdapterView.OnItemClickListener onItemClickListener = new AdapterView.OnItemClickListener(){
        @Override
        public void onItemClick(AdapterView<?> adapterView, View view, int i, long l) {
            if (DocumentoActivity.getDocumento().getId() == 0) {
                Socio socio = (Socio) adapterView.getItemAtPosition(i);
                DocumentoActivity.setSocio(socio);
                EstablecerSocio();
            }
        }
    };

    private class editTextWatcher implements TextWatcher {
        @Override
        public void beforeTextChanged (CharSequence s, int start, int count, int after) {

        }

        @Override
        public void onTextChanged (CharSequence s, int start, int before, int count) {

        }

        @Override
        public void afterTextChanged (Editable s) {
            DocumentoActivity.getDocumento().setComentario(editTextComentario.getText().toString());
        }
    }

    private Boolean Cargar()
    {
        try {
            if (DocumentoActivity.getDocumento() != null) {
                Serie serie = (DocumentoActivity.getDocumento().getId() == 0) ? Serie.ObtenerPredeterminado(DocumentoActivity.getDocumento().getClase()) : Serie.Obtener(DocumentoActivity.getDocumento().getSerie_id());
                if (serie != null) {
                    textViewSerie.setText(serie.getNombre());
                    DocumentoActivity.getDocumento().setSerie_id(serie.getId());
                }
                textViewID.setText(DocumentoActivity.getDocumento().getId().toString());
                textViewFechaDocumento.setText(Functions.toDateTimeString(DocumentoActivity.getDocumento().getFecha_documento()));

                if (DocumentoActivity.getDocumento().getSocio_id() != 0) {
                    EstablecerSocio();
                }

                editTextComentario.setText(DocumentoActivity.getDocumento().getComentario());

                return true;
            }

            return  false;
        } catch (Exception ex) {
            Toast.makeText(getContext(), ex.getMessage(), Toast.LENGTH_SHORT).show();
            return false;
        }
    }

    private void EstablecerSocio() {
        try {
            Boolean socio_establecido = (DocumentoActivity.getDocumento().getId() != 0) ? true : DocumentoActivity.getDocumento().EstablecerSocio(DocumentoActivity.getSocio());
            if (socio_establecido) {
                autoCompleteTextViewCodigoSN.setText(DocumentoActivity.getSocio().getCodigo());
                textViewSocio.setText(DocumentoActivity.getSocio().getNombre());

                Vendedor vendedor = Vendedor.Obtener(DocumentoActivity.getDocumento().getVendedor_id());
                if (vendedor != null) {
                    textViewVendedor.setText(vendedor.getNombre());
                }

                Moneda moneda = Moneda.Obtener(DocumentoActivity.getDocumento().getMoneda_id());
                if (moneda != null) {
                    textViewMoneda.setText(moneda.getNombre());
                }

                spinnerListasPrecios.setEnabled((DocumentoActivity.getDocumento().getSocio_id().equals(Global.getUsuario().getSocio_id())) ? true : false);
            }
        } catch (Exception ex) {
            Toast.makeText(getContext(), ex.getMessage(), Toast.LENGTH_SHORT).show();
        }
    }
}
