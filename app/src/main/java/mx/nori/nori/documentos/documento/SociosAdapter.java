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

import mx.nori.nori.NoriSDK.Socio;
import mx.nori.nori.R;

public class SociosAdapter extends ArrayAdapter<Socio> {
    private LayoutInflater layoutInflater;
    List<Socio> mSocios;

    private Filter mFilter = new Filter() {
        @Override
        public String convertResultToString(Object resultValue) {
            return ((Socio)resultValue).getNombre();
        }

        @Override
        protected FilterResults performFiltering(CharSequence constraint) {
            FilterResults results = new FilterResults();

            if (constraint != null) {
                ArrayList<Socio> suggestions = new ArrayList<>();

                if (mSocios != null) {
                    for (Socio socio : mSocios) {
                        // Note: change the "contains" to "startsWith" if you only want starting matches
                        if (socio.getCodigo().toLowerCase().contains(constraint.toString().toLowerCase())) {
                            suggestions.add(socio);
                        } else if (socio.getNombre().toLowerCase().contains(constraint.toString().toLowerCase())) {
                            suggestions.add(socio);
                        }
                    }
                }

                results.values = suggestions;
                results.count = suggestions.size();
            }

            return results;
        }

        @Override
        protected void publishResults(CharSequence constraint, FilterResults results) {
            try {
                clear();
                if (results != null && results.count > 0) {
                    // we have filtered results
                    addAll((ArrayList<Socio>) results.values);
                } else {
                    // no filter, add entire original list back in
                    addAll(mSocios);
                }
                notifyDataSetChanged();
            } catch (Exception ex) {
                //
            }
        }
    };

    public SociosAdapter(Context context, int textViewResourceId, List<Socio> socios) {
        super(context, textViewResourceId, socios);
        // copy all the socios into a master list
        if (socios != null) {
            mSocios = new ArrayList<>(socios.size());
            mSocios.addAll(socios);
            layoutInflater = (LayoutInflater) getContext().getSystemService(Context.LAYOUT_INFLATER_SERVICE);
        }
    }

    @Override
    public View getView(int position, View convertView, ViewGroup parent) {
        View view = convertView;

        if (view == null) {
            view = layoutInflater.inflate(R.layout.recyclerview_codigo_nombre, null);
        }

        Socio socio = getItem(position);

        TextView textViewCodigo = view.findViewById(R.id.textViewCodigo);
        TextView textViewNombre = view.findViewById(R.id.textViewCodigoSN);

        textViewCodigo.setText(socio.getCodigo());
        textViewNombre.setText(socio.getNombre());

        return view;
    }

    @Override
    public Filter getFilter() {
        return mFilter;
    }
}