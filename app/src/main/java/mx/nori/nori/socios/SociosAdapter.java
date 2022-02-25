package mx.nori.nori.socios;

import android.content.Context;
import android.content.Intent;
import android.net.Uri;
import android.support.v7.widget.PopupMenu;
import android.support.v7.widget.RecyclerView;
import android.view.LayoutInflater;
import android.view.MenuItem;
import android.view.View;
import android.view.ViewGroup;
import android.widget.TextView;
import android.widget.Toast;

import java.util.List;

import mx.nori.nori.NoriSDK.Documento;
import mx.nori.nori.NoriSDK.Socio;
import mx.nori.nori.R;
import mx.nori.nori.actividad.ActividadActivity;
import mx.nori.nori.documentos.documento.DocumentoActivity;

public class SociosAdapter extends RecyclerView.Adapter<SociosAdapter.ViewHolder> {
    private List<Socio> mDataset;
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
            textViewNombre = itemView.findViewById(R.id.textViewCodigoSN);
            textViewCodigo = itemView.findViewById(R.id.textViewCodigo);
            itemView.setOnClickListener(this);
        }

        @Override
        public void onClick(final View view) {
            if (mClickListener != null) mClickListener.onItemClick(view, getAdapterPosition());
            final Context context = view.getContext();
            PopupMenu popup = new PopupMenu(context, view);
            popup.getMenuInflater().inflate(R.menu.socios, popup.getMenu());
            popup.setOnMenuItemClickListener(new PopupMenu.OnMenuItemClickListener() {
                @Override
                public boolean onMenuItemClick(MenuItem item) {
                    switch (item.getItemId()) {
                        case R.id.cotizacion:
                            Intent intent_cotizacion = new Intent(context, DocumentoActivity.class);
                            intent_cotizacion.putExtra("clase", "CO");
                            intent_cotizacion.putExtra("socio_id", (mDataset.get(getAdapterPosition()).getId()));
                            context.startActivity(intent_cotizacion);
                            break;
                        case R.id.pedido:
                            Intent intent_pedido = new Intent(context, DocumentoActivity.class);
                            intent_pedido.putExtra("clase", "PE");
                            intent_pedido.putExtra("socio_id", (mDataset.get(getAdapterPosition()).getId()));
                            context.startActivity(intent_pedido);
                            break;
                        case R.id.entrega:
                            Intent intent_entrega = new Intent(context, DocumentoActivity.class);
                            intent_entrega.putExtra("clase", "EN");
                            intent_entrega.putExtra("socio_id", (mDataset.get(getAdapterPosition()).getId()));
                            context.startActivity(intent_entrega);
                            break;
                        case R.id.factura:
                            Intent intent_factura = new Intent(context, DocumentoActivity.class);
                            intent_factura.putExtra("clase", "FA");
                            intent_factura.putExtra("socio_id", (mDataset.get(getAdapterPosition()).getId()));
                            context.startActivity(intent_factura);
                            break;
                        case R.id.actividad:
                            Intent intent = new Intent(context, ActividadActivity.class);
                            intent.putExtra("socio_id", (mDataset.get(getAdapterPosition()).getId()));
                            context.startActivity(intent);
                            break;
                        case R.id.ubicacion:
                            Uri gmmIntentUri = Uri.parse("google.navigation:q=" + mDataset.get(getAdapterPosition()).getLatitud() + "," + mDataset.get(getAdapterPosition()).getLongitud());
                            Intent mapIntent = new Intent(Intent.ACTION_VIEW, gmmIntentUri);
                            mapIntent.setPackage("com.google.android.apps.maps");
                            context.startActivity(mapIntent);
                            break;
                        case R.id.ver:
                            Toast.makeText(context, "Ver socio.", Toast.LENGTH_LONG).show();
                            break;
                    }
                    return true;
                }
            });
            popup.show();
        }
    }

    // Provide a suitable constructor (depends on the kind of dataset)
    public SociosAdapter(Context context, List<Socio> myDataset) {
        mInflater = LayoutInflater.from(context);
        mDataset = myDataset;
    }

    // Create new views (invoked by the layout manager)
    @Override
    public SociosAdapter.ViewHolder onCreateViewHolder(ViewGroup parent, int viewType) {
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
        holder.textViewCodigo.setText(mDataset.get(position).getCodigo());
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