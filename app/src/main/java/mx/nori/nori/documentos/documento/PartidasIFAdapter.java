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

import mx.nori.nori.NoriSDK.Almacen;
import mx.nori.nori.NoriSDK.Articulo;
import mx.nori.nori.NoriSDK.Documento;
import mx.nori.nori.NoriSDK.Global;
import mx.nori.nori.R;

public class PartidasIFAdapter extends RecyclerView.Adapter<PartidasIFAdapter.ViewHolder> {
    private List<Documento.Partida> mDataset;
    private LayoutInflater mInflater;
    private ItemClickListener mClickListener;
    private int position = 0;

    // Provide a reference to the views for each data item
    // Complex data items may need more than one view per item, and
    // you provide access to all the views for a data item in a view holder
    // stores and recycles views as they are scrolled off screen
    public class ViewHolder extends RecyclerView.ViewHolder implements View.OnClickListener {
        TextView textViewSKU, textViewNombre, textViewCodigoBarras, textViewAlmacen, textViewCantidad, textViewStock, textViewDiferencia;

        ViewHolder(final View itemView) {
            super(itemView);
            textViewSKU = itemView.findViewById(R.id.textViewSKU);
            textViewNombre = itemView.findViewById(R.id.textViewCodigoSN);
            textViewCodigoBarras = itemView.findViewById(R.id.textViewCodigoBarras);
            textViewAlmacen = itemView.findViewById(R.id.textViewAlmacen);
            textViewCantidad = itemView.findViewById(R.id.textViewCantidad);
            textViewStock = itemView.findViewById(R.id.textViewStock);
            textViewDiferencia = itemView.findViewById(R.id.textViewDiferencia);

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
    public PartidasIFAdapter(Context context, List<Documento.Partida> myDataset) {
        mInflater = LayoutInflater.from(context);
        mDataset = myDataset;
    }

    // Create new views (invoked by the layout manager)
    @Override
    public PartidasIFAdapter.ViewHolder onCreateViewHolder(ViewGroup parent, int viewType) {
        // create a new view
        View view = mInflater.inflate(R.layout.recyclerview_partida_inventario_fisico, parent, false);
        return new ViewHolder(view);
    }

    // Replace the contents of a view (invoked by the layout manager)
    @Override
    public void onBindViewHolder(ViewHolder holder, int position) {
        // - get element from your dataset at this position
        // - replace the contents of the view with that element
        holder.textViewSKU.setText(mDataset.get(position).getSku());
        holder.textViewNombre.setText(mDataset.get(position).getNombre());
        holder.textViewCodigoBarras.setText(mDataset.get(position).getCodigo_barras());
        holder.textViewCantidad.setText(mDataset.get(position).getCantidad().toString());

        Almacen almacen = Almacen.Obtener(mDataset.get(position).getAlmacen_id());

        if (almacen != null) {
            holder.textViewAlmacen.setText(almacen.getCodigo());
        } else {
            holder.textViewAlmacen.setText("");
        }

        if (almacen.getUbicaciones())
        {
            Articulo.Inventario.Ubicacion inventario = Articulo.Inventario.Ubicacion.Obtener(mDataset.get(position).getArticulo_id(), almacen.getId(), Global.getUsuario().getUbicacion_id());
            Almacen.Ubicacion ubicacion = Almacen.Ubicacion.Obtener(inventario.getUbicacion_id());
            if (inventario != null && ubicacion != null) {
                holder.textViewStock.setText(String.format("%s (%s)", inventario.getStock().toString(), ubicacion.getUbicacion()));
            } else {
                holder.textViewStock.setText("0");
            }
        }
        else
        {
            Articulo.Inventario inventario = Articulo.Inventario.Obtener(mDataset.get(position).getArticulo_id(), almacen.getId());
            if (inventario != null) {
                holder.textViewStock.setText(inventario.getStock().toString());
            } else {
                holder.textViewStock.setText("0");
            }
        }

        holder.textViewDiferencia.setText(mDataset.get(position).getDiferencia().toString());
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