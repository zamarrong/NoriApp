package mx.nori.nori.documentos;

import android.app.AlertDialog;
import android.content.Context;
import android.content.DialogInterface;
import android.content.Intent;
import android.graphics.Color;
import android.support.v7.widget.RecyclerView;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.TextView;
import android.widget.Toast;

import java.util.List;

import mx.nori.nori.Functions;
import mx.nori.nori.Impresora;
import mx.nori.nori.NoriSDK.Documento;
import mx.nori.nori.NoriSDK.Global;
import mx.nori.nori.NoriSDK.Socio;
import mx.nori.nori.R;
import mx.nori.nori.documentos.documento.DocumentoActivity;

public class DocumentosAdapter extends RecyclerView.Adapter<DocumentosAdapter.ViewHolder> {
    private List<Documento> mDataset;
    private LayoutInflater mInflater;
    private ItemClickListener mClickListener;
    Context context;
    private int position = 0;

    // Provide a reference to the views for each data item
    // Complex data items may need more than one view per item, and
    // you provide access to all the views for a data item in a view holder
    // stores and recycles views as they are scrolled off screen
    public class ViewHolder extends RecyclerView.ViewHolder implements View.OnClickListener {
        TextView textViewCodigoSN, textViewNombre, textViewFecha, textViewNumeroDocumento, textViewIdentificadorExterno, textViewTotal;

        ViewHolder(final View itemView) {
            super(itemView);
            context = itemView.getContext();

            textViewCodigoSN = itemView.findViewById(R.id.textViewCodigoSN);
            textViewNombre = itemView.findViewById(R.id.textViewNombre);
            textViewFecha = itemView.findViewById(R.id.textViewFecha);
            textViewNumeroDocumento = itemView.findViewById(R.id.textViewID);
            textViewIdentificadorExterno = itemView.findViewById(R.id.textViewIdentificadorExterno);
            textViewTotal = itemView.findViewById(R.id.textViewTipoActividad);

            itemView.setOnLongClickListener(new View.OnLongClickListener() {
                @Override
                public boolean onLongClick(View view) {
                    position = getAdapterPosition();
                    AlertDialog.Builder builder = new AlertDialog.Builder(itemView.getContext());
                    builder.setMessage("¿Cancelar documento?").setPositiveButton("Si", dialogClickListener).setNegativeButton("No", dialogClickListener).show();
                    return true;
                }
            });

            itemView.setOnClickListener(this);
        }

        @Override
        public void onClick(View view) {
            if (mClickListener != null) mClickListener.onItemClick(view, getAdapterPosition());
            Intent intent = new Intent(context, DocumentoActivity.class);
            intent.putExtra("id", (mDataset.get(getAdapterPosition()).getId()));
            context.startActivity(intent);
        }
    }

    DialogInterface.OnClickListener dialogClickListener = new DialogInterface.OnClickListener() {
        @Override
        public void onClick(DialogInterface dialog, int which) {
            switch (which){
                case DialogInterface.BUTTON_POSITIVE:
                    if (mDataset.get(position).Cancelar()) {
                        try {
                            Impresora impresora = new Impresora();
                            impresora.ImprimirDocumento(mDataset.get(position));
                        } catch (Exception e) {}
                    } else {
                        Toast.makeText(context, Global.getError().getMessage(), Toast.LENGTH_LONG).show();
                    }
                    break;
            }
        }
    };

    // Provide a suitable constructor (depends on the kind of dataset)
    public DocumentosAdapter(Context context, List<Documento> myDataset) {
        mInflater = LayoutInflater.from(context);
        mDataset = myDataset;
    }

    // Create new views (invoked by the layout manager)
    @Override
    public DocumentosAdapter.ViewHolder onCreateViewHolder(ViewGroup parent, int viewType) {
        // create a new view
        View view = mInflater.inflate(R.layout.recyclerview_documento, parent, false);
        return new ViewHolder(view);
    }

    // Replace the contents of a view (invoked by the layout manager)
    @Override
    public void onBindViewHolder(ViewHolder holder, int position) {
        // - get element from your dataset at this position
        // - replace the contents of the view with that element
        Socio socio = Socio.Obtener(mDataset.get(position).getSocio_id());
        holder.textViewCodigoSN.setText(mDataset.get(position).getCodigo_sn().toString());
        if (socio != null) {
            holder.textViewNombre.setText(socio.getNombre());
        }
        holder.textViewFecha.setText(Functions.toDateString(mDataset.get(position).getFecha_documento()));
        holder.textViewNumeroDocumento.setText(mDataset.get(position).getNumero_documento().toString());
        if (mDataset.get(position).getIdentificador_externo() != 0) {
            holder.textViewNumeroDocumento.setTextColor(Color.argb(255, 102, 153, 1));
            holder.textViewIdentificadorExterno.setText(mDataset.get(position).getIdentificador_externo().toString());
        } else {
            holder.textViewIdentificadorExterno.setText("");
        }

        if (mDataset.get(position).getCancelado())
        {
            holder.textViewNumeroDocumento.setTextColor(Color.argb(255, 217, 30, 24));
            holder.textViewIdentificadorExterno.setText("CANCELADO");
        }

        holder.textViewTotal.setText(Functions.toCurrency(mDataset.get(position).getTotal()));
    }

    // Return the size of your dataset (invoked by the layout manager)
    @Override
    public int getItemCount() {
        if (mDataset == null) {
            return 0;
        } else {
            return mDataset.size();
        }
    }

    // allows clicks events to be caught
    void setClickListener(ItemClickListener itemClickListener) {
        this.mClickListener = itemClickListener;
    }

    // parent activity will implement this method to respond to click events
    public interface ItemClickListener {
        void onItemClick(View view, int position);
    }
}