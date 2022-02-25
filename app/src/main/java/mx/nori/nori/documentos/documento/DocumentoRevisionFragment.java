package mx.nori.nori.documentos.documento;

import android.app.AlertDialog;
import android.content.DialogInterface;
import android.os.Bundle;
import android.support.v4.app.Fragment;
import android.support.v7.widget.DividerItemDecoration;
import android.support.v7.widget.LinearLayoutManager;
import android.support.v7.widget.RecyclerView;
import android.view.LayoutInflater;
import android.view.Menu;
import android.view.MenuInflater;
import android.view.MenuItem;
import android.view.View;
import android.view.ViewGroup;
import android.widget.TextView;
import android.widget.Toast;

import mx.nori.nori.Functions;
import mx.nori.nori.Impresora;
import mx.nori.nori.NoriSDK.Documento;
import mx.nori.nori.NoriSDK.Global;
import mx.nori.nori.NoriSDK.Moneda;
import mx.nori.nori.NoriSDK.Serie;
import mx.nori.nori.NoriSDK.Vendedor;
import mx.nori.nori.R;

public class DocumentoRevisionFragment extends Fragment {

    TextView textViewSerie, textViewID, textViewFechaDocumento, textViewSocio, textViewMoneda, textViewVendedor,
             textViewComentario, textViewSubTotal, textViewDescuento, textViewImpuesto, textViewTotal;
    RecyclerView mRecyclerView;

    @Override
    public View onCreateView(LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
        // Inflate the layout for this fragment
        setHasOptionsMenu(true);
        final View view = inflater.inflate(R.layout.fragment_documento_revision, container, false);

        textViewSerie = view.findViewById(R.id.textViewSerie);
        textViewID = view.findViewById(R.id.textViewID);
        textViewFechaDocumento = view.findViewById(R.id.textViewFechaDocumento);
        textViewSocio = view.findViewById(R.id.textViewSocio);
        textViewMoneda = view.findViewById(R.id.textViewMoneda);
        textViewVendedor = view.findViewById(R.id.textViewVendedor);
        textViewComentario = view.findViewById(R.id.textViewComentario);
        textViewSubTotal = view.findViewById(R.id.textViewSubTotal);
        textViewDescuento = view.findViewById(R.id.textViewDescuento);
        textViewImpuesto = view.findViewById(R.id.textViewImpuesto);
        textViewTotal = view.findViewById(R.id.textViewTipoActividad);

        mRecyclerView = view.findViewById(R.id.recyclerView);
        mRecyclerView.setHasFixedSize(true);

        RecyclerView.LayoutManager mLayoutManager = new LinearLayoutManager(getActivity());
        mRecyclerView.setLayoutManager(mLayoutManager);
        mRecyclerView.addItemDecoration(new DividerItemDecoration(getActivity(), DividerItemDecoration.VERTICAL));

        return view;
    }

    @Override
    public void onCreateOptionsMenu(Menu menu, MenuInflater inflater) {
        menu.clear();
        inflater.inflate(R.menu.documento, menu);
        super.onCreateOptionsMenu(menu, inflater);
    }

    @Override
    public void setUserVisibleHint(boolean isVisibleToUser) {
        super.setUserVisibleHint(isVisibleToUser);
        if (isVisibleToUser) {
            Cargar();
        }
    }

    @Override
    public boolean onOptionsItemSelected(MenuItem item) {
        switch (item.getItemId()) {
            case R.id.guardar:
                if (DocumentoActivity.getDocumento().getImporte_aplicado() < DocumentoActivity.getDocumento().getTotal() && DocumentoActivity.getDocumento().getClase().equals("EN")) {
                    AlertDialog.Builder builder = new AlertDialog.Builder(getContext());
                    builder.setMessage("¿Desea guardar este documento a crédito?").setPositiveButton("Si", dialogClickListener).setNegativeButton("No", dialogClickListener).show();
                } else {
                    Guardar();
                }
                return true;
            case R.id.imprimir:
                if (DocumentoActivity.getDocumento().getId() != 0) {
                    Impresora impresora = new Impresora();
                    impresora.ImprimirDocumento(DocumentoActivity.getDocumento());
                } else {
                    Toast.makeText(getContext(), "El documento aún no ha sido guardado.", Toast.LENGTH_SHORT).show();
                }
                return true;
        }
        return super.onOptionsItemSelected(item);
    }

    DialogInterface.OnClickListener dialogClickListener = new DialogInterface.OnClickListener() {
        @Override
        public void onClick(DialogInterface dialog, int which) {
            switch (which){
                case DialogInterface.BUTTON_POSITIVE:
                    Guardar();
                    break;
            }
        }
    };

    private Boolean Guardar() {
        try {
            if (DocumentoActivity.getDocumento().getId() == 0) {
                if (DocumentoActivity.getDocumento().Agregar()) {
                    Toast.makeText(getContext(), "Información guardada correctamente.", Toast.LENGTH_SHORT).show();
                } else {
                    Toast.makeText(getContext(), Global.getError().getMessage(), Toast.LENGTH_SHORT).show();
                }
            } else {
                Toast.makeText(getContext(), "Ya ha sido guardado el documento.", Toast.LENGTH_SHORT).show();
            }
            return true;
        } catch (Exception ex) {
            Toast.makeText(getContext(), ex.getMessage(), Toast.LENGTH_SHORT).show();
            return  false;
        }
    }

    private Boolean Cargar() {
        try {
            if (DocumentoActivity.getDocumento() != null) {
                Serie serie = (DocumentoActivity.getDocumento().getId() == 0) ? Serie.ObtenerPredeterminado(DocumentoActivity.getDocumento().getClase()) : Serie.Obtener(DocumentoActivity.getDocumento().getSerie_id());
                if (serie != null) {
                    textViewSerie.setText(serie.getNombre());
                    DocumentoActivity.getDocumento().setSerie_id(serie.getId());
                }
                textViewID.setText(DocumentoActivity.getDocumento().getId().toString());
                textViewFechaDocumento.setText(Functions.toDateTimeString(DocumentoActivity.getDocumento().getFecha_documento()));

                textViewSocio.setText(DocumentoActivity.getSocio().getNombre());

                Vendedor vendedor = Vendedor.Obtener(DocumentoActivity.getDocumento().getVendedor_id());
                if (vendedor != null) {
                    textViewVendedor.setText(vendedor.getNombre());
                }

                Moneda moneda = Moneda.Obtener(DocumentoActivity.getDocumento().getMoneda_id());
                if (moneda != null) {
                    textViewMoneda.setText(moneda.getNombre());
                }

                textViewComentario.setText(DocumentoActivity.getDocumento().getComentario());

                DocumentoActivity.getDocumento().CalcularTotal();

                textViewSubTotal.setText(Functions.toCurrency(DocumentoActivity.getDocumento().getSubtotal()));
                textViewDescuento.setText(Functions.toCurrency(DocumentoActivity.getDocumento().getDescuento()));
                textViewImpuesto.setText(Functions.toCurrency(DocumentoActivity.getDocumento().getImpuesto()));
                textViewTotal.setText(Functions.toCurrency(DocumentoActivity.getDocumento().getTotal()));

                RecyclerView.Adapter mAdapter = (DocumentoActivity.getDocumento().getClase().equals("IF")) ? new PartidasIFAdapter(getActivity(), DocumentoActivity.getDocumento().getPartidas()) : new PartidasAdapter(getActivity(), DocumentoActivity.getDocumento().getPartidas());
                mRecyclerView.setAdapter(mAdapter);
                return true;
            }

            return  false;
        } catch (Exception ex) {
            Toast.makeText(getContext(), ex.getMessage(), Toast.LENGTH_SHORT).show();
            return false;
        }
    }
}
