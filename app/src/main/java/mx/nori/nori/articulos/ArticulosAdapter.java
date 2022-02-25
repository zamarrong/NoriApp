package mx.nori.nori.articulos;

import android.content.Context;
import android.content.Intent;
import android.support.v7.widget.RecyclerView;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.TextView;

import java.util.List;

import mx.nori.nori.articulos.articulo.ArticuloActivity;
import mx.nori.nori.NoriSDK.Articulo;
import mx.nori.nori.R;

public class ArticulosAdapter extends RecyclerView.Adapter<ArticulosAdapter.ViewHolder> {
    private List<Articulo> mDataset;
    private LayoutInflater mInflater;
    private ItemClickListener mClickListener;

    // Provide a reference to the views for each data item
    // Complex data items may need more than one view per item, and
    // you provide access to all the views for a data item in a view holder
    // stores and recycles views as they are scrolled off screen
    public class ViewHolder extends RecyclerView.ViewHolder implements View.OnClickListener {
        TextView textViewCodigo, textViewNombre;

        ViewHolder(View itemView) {
            super(itemView);
            textViewCodigo = itemView.findViewById(R.id.textViewCodigo);
            textViewNombre = itemView.findViewById(R.id.textViewCodigoSN);
            itemView.setOnClickListener(this);
        }

        @Override
        public void onClick(View view) {
            if (mClickListener != null) mClickListener.onItemClick(view, getAdapterPosition());
            Context context = view.getContext();
            Intent intent = new Intent(context, ArticuloActivity.class);
            intent.putExtra("id", (mDataset.get(getAdapterPosition()).getId()));
            context.startActivity(intent);
        }
    }

    // Provide a suitable constructor (depends on the kind of dataset)
    public ArticulosAdapter(Context context, List<Articulo> myDataset) {
        mInflater = LayoutInflater.from(context);
        mDataset = myDataset;
    }

    // Create new views (invoked by the layout manager)
    @Override
    public ArticulosAdapter.ViewHolder onCreateViewHolder(ViewGroup parent, int viewType) {
        // create a new view
        View view = mInflater.inflate(R.layout.recyclerview_codigo_nombre, parent, false);
        return new ViewHolder(view);
    }

    // Replace the contents of a view (invoked by the layout manager)
    @Override
    public void onBindViewHolder(ViewHolder holder, int position) {
        // - get element from your dataset at this position
        // - replace the contents of the view with that element
        holder.textViewNombre.setText(mDataset.get(position).getNombre());
        holder.textViewCodigo.setText(mDataset.get(position).getSku());
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