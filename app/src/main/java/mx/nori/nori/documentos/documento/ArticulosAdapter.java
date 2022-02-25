package mx.nori.nori.documentos.documento;

import android.content.Context;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ArrayAdapter;
import android.widget.Filter;
import android.widget.TextView;

import java.util.ArrayList;
import java.util.List;

import mx.nori.nori.NoriSDK.Articulo;
import mx.nori.nori.R;

public class ArticulosAdapter extends ArrayAdapter<Articulo> {
    private LayoutInflater layoutInflater;
    List<Articulo> mArticulos;

    private Filter mFilter = new Filter() {
        @Override
        public String convertResultToString(Object resultValue) {
            return ((Articulo)resultValue).getNombre();
        }

        @Override
        protected FilterResults performFiltering(CharSequence constraint) {
            FilterResults results = new FilterResults();

            if (constraint != null) {
                ArrayList<Articulo> suggestions = new ArrayList<>();
                for (Articulo articulo : mArticulos) {
                    // Note: change the "contains" to "startsWith" if you only want starting matches
                    if (articulo.getSku().toLowerCase().contains(constraint.toString().toLowerCase())) {
                        suggestions.add(articulo);
                    } else if (articulo.getNombre().toLowerCase().contains(constraint.toString().toLowerCase())) {
                        suggestions.add(articulo);
                    }
                }

                results.values = suggestions;
                results.count = suggestions.size();
            }

            return results;
        }

        @Override
        protected void publishResults(CharSequence constraint, FilterResults results) {
            clear();
            if (results != null && results.count > 0) {
                // we have filtered results
                addAll((ArrayList<Articulo>) results.values);
            } else {
                // no filter, add entire original list back in
                addAll(mArticulos);
            }
            notifyDataSetChanged();
        }
    };

    public ArticulosAdapter(Context context, int textViewResourceId, List<Articulo> articulos) {
        super(context, textViewResourceId, articulos);
        // copy all the articulos into a master list
        mArticulos = new ArrayList<>(articulos.size());
        mArticulos.addAll(articulos);
        layoutInflater = (LayoutInflater) getContext().getSystemService(Context.LAYOUT_INFLATER_SERVICE);
    }

    @Override
    public View getView(int position, View convertView, ViewGroup parent) {
        View view = convertView;

        if (view == null) {
            view = layoutInflater.inflate(R.layout.recyclerview_codigo_nombre, null);
        }

        Articulo articulo = getItem(position);

        TextView textViewCodigo = view.findViewById(R.id.textViewCodigo);
        TextView textViewNombre = view.findViewById(R.id.textViewCodigoSN);

        textViewCodigo.setText(articulo.getSku());
        textViewNombre.setText(articulo.getNombre());

        return view;
    }

    @Override
    public Filter getFilter() {
        return mFilter;
    }
}