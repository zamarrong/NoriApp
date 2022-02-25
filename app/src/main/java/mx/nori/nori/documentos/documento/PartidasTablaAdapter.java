package mx.nori.nori.documentos.documento;

import android.annotation.SuppressLint;
import android.app.AlertDialog;
import android.content.Context;
import android.content.DialogInterface;
import android.support.v7.widget.RecyclerView;
import android.text.Editable;
import android.text.TextWatcher;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.EditText;
import android.widget.TextView;

import java.util.List;

import mx.nori.nori.Functions;
import mx.nori.nori.NoriSDK.Almacen;
import mx.nori.nori.NoriSDK.Documento;
import mx.nori.nori.R;

public class PartidasTablaAdapter extends RecyclerView.Adapter<PartidasTablaAdapter.ViewHolder> {
    private List<Documento.Partida> mDataset;
    private LayoutInflater mInflater;
    private ItemClickListener mClickListener;
    private int position = 0;
    boolean binded = false;

    // Provide a reference to the views for each data item
    // Complex data items may need more than one view per item, and
    // you provide access to all the views for a data item in a view holder
    // stores and recycles views as they are scrolled off screen
    public class ViewHolder extends RecyclerView.ViewHolder implements View.OnClickListener {
        TextView textViewSKU, textViewNombre;
        EditText editTextCantidad, editTextPrecio, editTextTotal;

        ViewHolder(final View itemView) {
            super(itemView);
            textViewSKU = itemView.findViewById(R.id.textViewSKU);
            textViewNombre = itemView.findViewById(R.id.textViewCodigoSN);
            editTextCantidad = itemView.findViewById(R.id.editTextCantidad);
            editTextPrecio = itemView.findViewById(R.id.editTextPrecio);
            editTextTotal = itemView.findViewById(R.id.editTextTotal);

            itemView.setOnClickListener(this);

            itemView.setOnLongClickListener(new View.OnLongClickListener() {
                @Override
                public boolean onLongClick(View view) {
                    if (DocumentoActivity.getDocumento().getId() == 0) {
                        position = getAdapterPosition();
                        AlertDialog.Builder builder = new AlertDialog.Builder(itemView.getContext());
                        builder.setMessage("¿Eliminar partida?").setPositiveButton("Si", dialogClickListener).setNegativeButton("No", dialogClickListener).show();
                    }
                    return false;
                }
            });

            editTextCantidad.addTextChangedListener(new TextWatcher() {

                public void onTextChanged(CharSequence c, int start, int before, int count) {
                    if (binded && !editTextCantidad.getText().toString().isEmpty()) {
                        position = getAdapterPosition();
                        mDataset.get(position).setCantidad(Double.parseDouble(editTextCantidad.getText().toString()));
                        CalcularTotal(position);
                    }
                }

                public void beforeTextChanged(CharSequence c, int start, int count, int after) {
                    //
                }

                public void afterTextChanged(Editable c) {
                    // this one too
                }
            });

            editTextPrecio.addTextChangedListener(new TextWatcher() {

                public void onTextChanged(CharSequence c, int start, int before, int count) {
                    if (binded && !editTextPrecio.getText().toString().isEmpty()) {
                        position = getAdapterPosition();
                        mDataset.get(position).setPrecio(Double.parseDouble(editTextPrecio.getText().toString()) * DocumentoActivity.getDocumento().getTipo_cambio());
                        CalcularTotal(position);
                    }
                }

                public void beforeTextChanged(CharSequence c, int start, int count, int after) {
                    //
                }

                public void afterTextChanged(Editable c) {
                    // this one too
                }
            });
        }

        @Override
        public void onClick(View view) {
            if (mClickListener != null) mClickListener.onItemClick(view, getAdapterPosition());
        }

        private void CalcularTotal(int position) {
            mDataset.get(position).CalcularTotal();
            editTextTotal.setText(Functions.toCurrency(mDataset.get(position).getTotal()));
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
    public PartidasTablaAdapter(Context context, List<Documento.Partida> myDataset) {
        mInflater = LayoutInflater.from(context);
        mDataset = myDataset;
    }

    // Create new views (invoked by the layout manager)
    @Override
    public PartidasTablaAdapter.ViewHolder onCreateViewHolder(ViewGroup parent, int viewType) {
        // create a new view
        View view = mInflater.inflate(R.layout.recyclerview_partida_tabla, parent, false);
        return new ViewHolder(view);
    }

    // Replace the contents of a view (invoked by the layout manager)
    @SuppressLint("SetTextI18n")
    @Override
    public void onBindViewHolder(ViewHolder holder, int position) {
        // - get element from your dataset at this position
        // - replace the contents of the view with that element
        holder.textViewSKU.setText(mDataset.get(position).getSku());
        holder.textViewNombre.setText(mDataset.get(position).getNombre());
        holder.editTextCantidad.setText(mDataset.get(position).getCantidad().toString());
        holder.editTextPrecio.setText(mDataset.get(position).getPrecio().toString());
        holder.editTextTotal.setText(Functions.toCurrency(mDataset.get(position).getTotal()));

        binded = true;
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