package mx.nori.nori.mas;

import android.app.Fragment;
import android.os.Bundle;
import android.view.LayoutInflater;
import android.view.Menu;
import android.view.MenuInflater;
import android.view.MenuItem;
import android.view.View;
import android.view.ViewGroup;
import android.widget.CheckBox;
import android.widget.EditText;
import android.widget.TextView;

import java.util.concurrent.ExecutionException;

import mx.nori.nori.MainActivity;
import mx.nori.nori.NoriSDK.Global;
import mx.nori.nori.R;

public class ConfiguracionFragment extends Fragment {
    TextView textViewIMEI;
    EditText editTextAPIRUL;
    CheckBox checkBoxModoRapido, checkBoxModoVivo;

    @Override
    public View onCreateView(LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
        // Inflate the layout for this fragment
        setHasOptionsMenu(true);
        final View view = inflater.inflate(R.layout.fragment_configuracion, container, false);
        ((MainActivity) getActivity()).getSupportActionBar().setTitle("Configuración");

        textViewIMEI = view.findViewById(R.id.textViewIMEI);
        editTextAPIRUL = view.findViewById(R.id.editTextAPIURL);
        checkBoxModoRapido = view.findViewById(R.id.checkBoxModoRapido);
        checkBoxModoVivo = view.findViewById(R.id.checkBoxModoVivo);

        editTextAPIRUL.setText(Global.getConfiguracion().getApi_url());
        checkBoxModoRapido.setChecked(Global.getConfiguracion().getModo_rapido());
        checkBoxModoVivo.setChecked(Global.getConfiguracion().getModo_vivo());
        textViewIMEI.setText(Global.getIMEI());

        return view;
    }

    @Override
    public void onCreateOptionsMenu(Menu menu, MenuInflater inflater) {
        menu.clear();
        inflater.inflate(R.menu.menu_guardar, menu);
        super.onCreateOptionsMenu(menu, inflater);
    }

    @Override
    public boolean onOptionsItemSelected(MenuItem item) {
        switch (item.getItemId()) {
            case R.id.guardar:
                Guardar();
                return true;
        }
        return super.onOptionsItemSelected(item);
    }

    private Boolean Guardar() {
        try {
            Global.getConfiguracion().setApi_url(editTextAPIRUL.getText().toString());
            Global.getConfiguracion().setModo_rapido(checkBoxModoRapido.isChecked());
            Global.getConfiguracion().setModo_vivo(checkBoxModoVivo.isChecked());

            return Global.getConfiguracion().Actualizar();
        } catch (Exception ex) {
            return false;
        }
    }
}
