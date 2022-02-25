package mx.nori.nori.documentos.documento;

import android.app.AlertDialog;
import android.content.Context;
import android.content.DialogInterface;
import android.support.v7.widget.RecyclerView;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.TextView;

import java.util.List;

import mx.nori.nori.Functions;
import mx.nori.nori.NoriSDK.Flujo;
import mx.nori.nori.NoriSDK.MetodoPago;
import mx.nori.nori.R;

public class FlujoAdapter extends RecyclerView.Adapter<FlujoAdapter.ViewHolder> {
    private List<Flujo> mDataset;
    private LayoutInflater mInflater;
    private ItemClickListener mClickListener;
    private int position = 0;

    // Provide a reference to the views for each data item
    // Complex data items may need more than one view per item, and
    // you provide access to all the views for a data item in a view holder
    // stores and recycles views as they are scrolled off screen
    public class ViewHolder extends RecyclerView.ViewHolder implements View.OnClickListener {
        TextView textViewCodigo, textViewNombre;

        ViewHolder(final View itemView) {
            super(itemView);
            textViewCodigo = itemView.findViewById(R.id.textViewCodigo);
            textViewNombre = itemView.findViewById(R.id.textViewCodigoSN);

            itemView.setOnClickListener(this);

            itemView.setOnLongClickListener(new View.OnLongClickListener() {
                @Override
                public boolean onLongClick(View view) {
                    if (DocumentoActivity.getDocumento().getId() == 0) {
                        position = getAdapterPosition();
                        AlertDialog.Builder builder = new AlertDialog.Builder(itemView.getContext());
                        builder.setMessage("¿Eliminar pago?").setPositiveButton("Si", dialogClickListener).setNegativeButton("No", dialogClickListener).show();
                    }
                    return false;
                }
            });
        }

        @Override
        public void onClick(View view) {
            if (mClickListener != null) mClickListener.onItemClick(view, getAdapterPosition());
        }
    }

    DialogInterface.OnClickListener dialogClickListener = new DialogInterface.OnClickListener() {
        @Override
        public void onClick(DialogInterface dialog, int which) {
            switch (which){
                case DialogInterface.BUTTON_POSITIVE:
                    removeAt(position);
                    break;
            }
        }
    };

    // Provide a suitable constructor (depends on the kind of dataset)
    public FlujoAdapter(Context context, List<Flujo> myDataset) {
        mInflater = LayoutInflater.from(context);
        mDataset = myDataset;
    }

    // Create new views (invoked by the layout manager)
    @Override
    public FlujoAdapter.ViewHolder onCreateViewHolder(ViewGroup parent, int viewType) {
        // create a new view
        View view = mInflater.inflate(R.layout.recyclerview_codigo_nombre, parent, false);
        return new ViewHolder(view);
    }

    // Replace the contents of a view (invoked by the layout manager)
    @Override
    public void onBindViewHolder(ViewHolder holder, int position) {
        // - get element from your dataset at this position
        // - replace the contents of the view with that element
        holder.textViewNombre.setText(String.format("%s x %s = %s", mDataset.get(position).getTipo_cambio().toString(), mDataset.get(position).getImporte().toString(), Functions.toCurrency(mDataset.get(position).getTipo_cambio() * mDataset.get(position).getImporte())));
        MetodoPago.Tipo tipo_metodo_pago = MetodoPago.Tipo.Obtener(mDataset.get(position).getTipo_metodo_pago_id());
        if (tipo_metodo_pago != null) {
            holder.textViewCodigo.setText(tipo_metodo_pago.getNombre());
        }
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

    public void removeAt(int position) {
        mDataset.remove(position);
        notifyItemRemoved(position);
        notifyItemRangeChanged(position, mDataset.size());
    }
}