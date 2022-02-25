package mx.nori.nori.actividad;

import android.content.Context;
import android.content.Intent;
import android.graphics.Color;
import android.support.v7.widget.RecyclerView;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.TextView;

import java.util.List;

import mx.nori.nori.Functions;
import mx.nori.nori.NoriSDK.Actividad;
import mx.nori.nori.NoriSDK.Socio;
import mx.nori.nori.R;

public class ActividadesAdapter extends RecyclerView.Adapter<ActividadesAdapter.ViewHolder> {
    private List<Actividad> mDataset;
    private LayoutInflater mInflater;
    private ItemClickListener mClickListener;

    // Provide a reference to the views for each data item
    // Complex data items may need more than one view per item, and
    // you provide access to all the views for a data item in a view holder
    // stores and recycles views as they are scrolled off screen
    public class ViewHolder extends RecyclerView.ViewHolder implements View.OnClickListener {
        TextView textViewCodigoSN, textViewNombre, textViewFecha, textViewID, textViewIdentificadorExterno, textViewTipoActividad;

        ViewHolder(View itemView) {
            super(itemView);
            textViewCodigoSN = itemView.findViewById(R.id.textViewCodigoSN);
            textViewNombre = itemView.findViewById(R.id.textViewNombre);
            textViewFecha = itemView.findViewById(R.id.textViewFecha);
            textViewID = itemView.findViewById(R.id.textViewID);
            textViewIdentificadorExterno = itemView.findViewById(R.id.textViewIdentificadorExterno);
            textViewTipoActividad = itemView.findViewById(R.id.textViewTipoActividad);
            itemView.setOnClickListener(this);
        }

        @Override
        public void onClick(View view) {
            if (mClickListener != null) mClickListener.onItemClick(view, getAdapterPosition());
            Context context = view.getContext();
            Intent intent = new Intent(context, ActividadActivity.class);
            intent.putExtra("id", (mDataset.get(getAdapterPosition()).getId()));
            context.startActivity(intent);
        }
    }

    // Provide a suitable constructor (depends on the kind of dataset)
    public ActividadesAdapter(Context context, List<Actividad> myDataset) {
        mInflater = LayoutInflater.from(context);
        mDataset = myDataset;
    }

    // Create new views (invoked by the layout manager)
    @Override
    public ActividadesAdapter.ViewHolder onCreateViewHolder(ViewGroup parent, int viewType) {
        // create a new view
        View view = mInflater.inflate(R.layout.recyclerview_actividad, parent, false);
        return new ViewHolder(view);
    }

    // Replace the contents of a view (invoked by the layout manager)
    @Override
    public void onBindViewHolder(ViewHolder holder, int position) {
        // - get element from your dataset at this position
        // - replace the contents of the view with that element
        Socio socio = Socio.Obtener(mDataset.get(position).getSocio_id());
        if (socio != null) {
            holder.textViewCodigoSN.setText(socio.getCodigo());
            holder.textViewNombre.setText(socio.getNombre());
        }

        holder.textViewFecha.setText(Functions.toDateString(mDataset.get(position).getFecha_creacion()));
        holder.textViewID.setText(mDataset.get(position).getId().toString());
        if (mDataset.get(position).getIdentificador_externo() != null) {
            if (mDataset.get(position).getIdentificador_externo() != 0) {
                holder.textViewID.setTextColor(Color.argb(255, 102, 153, 0));
                holder.textViewIdentificadorExterno.setText(mDataset.get(position).getIdentificador_externo().toString());
            } else {
                holder.textViewIdentificadorExterno.setText("");
            }
        }

        Actividad.Tipo tipo_actividad = Actividad.Tipo.Obtener(mDataset.get(position).getTipo_actividad_id());
        if (tipo_actividad != null) {
            holder.textViewTipoActividad.setText(tipo_actividad.getNombre());
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
}